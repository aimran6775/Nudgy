//
//  NudgyLLMService.swift
//  Nudge
//
//  Phase 5: OpenAI GPT-4o conversational backend.
//  Handles all LLM communication — chat completions, streaming,
//  function calling, and one-shot generations.
//  Modular: swap provider by implementing a different backend.
//

import Foundation

// MARK: - LLM Response

/// Parsed response from the LLM.
struct LLMResponse {
    let content: String
    let toolCalls: [LLMToolCall]
    let finishReason: String?
    
    var hasToolCalls: Bool { !toolCalls.isEmpty }
}

/// A function call requested by the LLM.
struct LLMToolCall: Sendable {
    let id: String
    let functionName: String
    let arguments: String
    
    /// Parse arguments as JSON dictionary.
    func parsedArguments() -> [String: Any]? {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}

// MARK: - NudgyLLMService

/// Handles all LLM API communication for Nudgy.
@MainActor @Observable
final class NudgyLLMService {
    
    static let shared = NudgyLLMService()
    
    /// Whether the LLM is currently generating.
    private(set) var isGenerating = false
    
    /// Last error (for debugging).
    private(set) var lastError: String?
    
    private init() {}
    
    // MARK: - Chat Completion
    
    /// Send a chat completion request with function calling support.
    /// Returns the full response including any tool calls.
    func chatCompletion(
        messages: [[String: Any]],
        tools: [[String: Any]]? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> LLMResponse {
        isGenerating = true
        defer { isGenerating = false }
        
        let url = URL(string: "\(NudgyConfig.OpenAI.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(NudgyConfig.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        var body: [String: Any] = [
            "model": model ?? NudgyConfig.OpenAI.chatModel,
            "messages": messages,
            "temperature": temperature ?? NudgyConfig.OpenAI.conversationTemperature,
            "max_tokens": maxTokens ?? NudgyConfig.OpenAI.maxTokens,
        ]
        
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NudgyLLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            lastError = "HTTP \(httpResponse.statusCode): \(errorBody)"
            throw NudgyLLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        return try parseResponse(data)
    }
    
    // MARK: - Streaming Chat Completion
    
    /// Stream a chat completion response. Calls onPartial with each text chunk.
    /// Returns the final response with any tool calls.
    func streamChatCompletion(
        messages: [[String: Any]],
        tools: [[String: Any]]? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> LLMResponse {
        isGenerating = true
        defer { isGenerating = false }
        
        let url = URL(string: "\(NudgyConfig.OpenAI.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(NudgyConfig.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        var body: [String: Any] = [
            "model": model ?? NudgyConfig.OpenAI.chatModel,
            "messages": messages,
            "temperature": temperature ?? NudgyConfig.OpenAI.conversationTemperature,
            "max_tokens": maxTokens ?? NudgyConfig.OpenAI.maxTokens,
            "stream": true,
        ]
        
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NudgyLLMError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Stream failed")
        }
        
        var fullContent = ""
        var toolCalls: [String: (name: String, arguments: String)] = [:]
        var finishReason: String?
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            
            if jsonString == "[DONE]" { break }
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let choice = choices.first
            else { continue }
            
            if let reason = choice["finish_reason"] as? String {
                finishReason = reason
            }
            
            if let delta = choice["delta"] as? [String: Any] {
                // Text content
                if let content = delta["content"] as? String {
                    fullContent += content
                    onPartial(fullContent)
                }
                
                // Tool calls (accumulated across chunks)
                if let deltaToolCalls = delta["tool_calls"] as? [[String: Any]] {
                    for tc in deltaToolCalls {
                        let index = tc["index"] as? Int ?? 0
                        let key = "\(index)"
                        
                        if let id = tc["id"] as? String {
                            let funcInfo = tc["function"] as? [String: Any]
                            toolCalls[key] = (
                                name: funcInfo?["name"] as? String ?? "",
                                arguments: funcInfo?["arguments"] as? String ?? ""
                            )
                        } else if let funcInfo = tc["function"] as? [String: Any] {
                            // Append arguments chunk
                            if var existing = toolCalls[key] {
                                existing.arguments += funcInfo["arguments"] as? String ?? ""
                                toolCalls[key] = existing
                            }
                        }
                    }
                }
            }
        }
        
        let parsedToolCalls = toolCalls.sorted { $0.key < $1.key }.map { (key, value) in
            LLMToolCall(id: "call_\(key)", functionName: value.name, arguments: value.arguments)
        }
        
        return LLMResponse(
            content: fullContent,
            toolCalls: parsedToolCalls,
            finishReason: finishReason
        )
    }
    
    // MARK: - One-Shot Generation
    
    /// Quick one-shot generation (no tools, no conversation context).
    /// Used for greeting, reaction, and task extraction prompts.
    func generate(
        systemPrompt: String,
        userPrompt: String,
        model: String? = nil,
        temperature: Double? = nil
    ) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        
        let response = try await chatCompletion(
            messages: messages,
            model: model,
            temperature: temperature
        )
        
        return response.content
    }
    
    // MARK: - Text-to-Speech (OpenAI TTS)
    
    /// Generate speech audio from text using OpenAI TTS API.
    /// Returns audio data (mp3 format).
    func textToSpeech(
        text: String,
        voice: String? = nil,
        model: String? = nil
    ) async throws -> Data {
        let url = URL(string: "\(NudgyConfig.OpenAI.baseURL)/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(NudgyConfig.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "model": model ?? NudgyConfig.Voice.openAITTSModel,
            "input": text,
            "voice": voice ?? NudgyConfig.Voice.openAIVoice,
            "response_format": "mp3"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NudgyLLMError.apiError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "TTS failed"
            )
        }
        
        return data
    }
    
    // MARK: - Parse Response
    
    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first
        else {
            throw NudgyLLMError.parseError
        }
        
        let message = choice["message"] as? [String: Any] ?? [:]
        let content = message["content"] as? String ?? ""
        let finishReason = choice["finish_reason"] as? String
        
        var toolCalls: [LLMToolCall] = []
        if let rawToolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in rawToolCalls {
                let id = tc["id"] as? String ?? UUID().uuidString
                if let function = tc["function"] as? [String: Any] {
                    toolCalls.append(LLMToolCall(
                        id: id,
                        functionName: function["name"] as? String ?? "",
                        arguments: function["arguments"] as? String ?? "{}"
                    ))
                }
            }
        }
        
        return LLMResponse(
            content: content,
            toolCalls: toolCalls,
            finishReason: finishReason
        )
    }
}

// MARK: - Errors

enum NudgyLLMError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case notConfigured
    
    nonisolated var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let code, let message):
            return "AI service error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse AI response"
        case .notConfigured:
            return "AI service not configured"
        }
    }
}
