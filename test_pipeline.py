"""
Test the exact same OpenAI pipeline the Nudge app uses.
Mimics NudgyConversationManager → NudgyLLMService → OpenAI API.
Tests: chat completion, streaming, tool calls, and TTS.
"""
import requests
import json
import time

# Load API key
with open('/Users/abdullahimran/Desktop/untitled folder/Nudge/Secrets.xcconfig') as f:
    for line in f:
        if 'OPENAI_API_KEY' in line and '=' in line:
            API_KEY = line.split('=', 1)[1].strip()
            break

BASE_URL = "https://api.openai.com/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Same system prompt the app uses (from NudgyPersonality.swift)
SYSTEM_PROMPT = """You are Nudgy — a small, excitable penguin who lives inside someone's phone as their ADHD task companion.

YOUR BACKSTORY:
You're a penguin who waddled away from Antarctica because you found it "too organized" — ironic, since you now help humans organize their lives.

HOW YOU TALK:
- Like a friend texting — casual, warm, sometimes silly
- Short responses: 1-3 sentences usually
- Always include at least one emoji
- You're expressive: use italics (*happy waddle*), sound effects

TIME CONTEXT: It's evening, Saturday February 8"""

# Same tools the app defines (simplified)
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "lookup_tasks",
            "description": "Look up the user's tasks. Use when they ask about tasks or what they need to do.",
            "parameters": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["active", "completed", "snoozed", "all"],
                        "description": "Filter by task status"
                    }
                }
            }
        }
    }
]

def test_chat():
    """Test 1: Basic chat completion (same as NudgyLLMService.chatCompletion)"""
    print("=" * 60)
    print("TEST 1: Chat Completion (gpt-4o-mini)")
    print("=" * 60)
    
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": "Hey Nudgy! How are you?"}
    ]
    
    start = time.time()
    resp = requests.post(f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.85,
            "max_tokens": 300,
            "tools": TOOLS,
            "tool_choice": "auto"
        },
        timeout=30
    )
    elapsed = time.time() - start
    
    print(f"  Status: {resp.status_code}")
    print(f"  Time: {elapsed:.1f}s")
    
    if resp.status_code == 200:
        data = resp.json()
        choice = data["choices"][0]
        content = choice["message"].get("content", "")
        tool_calls = choice["message"].get("tool_calls", [])
        finish = choice.get("finish_reason", "")
        
        print(f"  Finish reason: {finish}")
        print(f"  Tool calls: {len(tool_calls)}")
        print(f"  Response: {content}")
        print(f"  ✅ PASS")
        return True
    else:
        print(f"  Error: {resp.text[:300]}")
        print(f"  ❌ FAIL")
        return False


def test_streaming():
    """Test 2: Streaming chat (same as NudgyLLMService.streamChatCompletion)"""
    print("\n" + "=" * 60)
    print("TEST 2: Streaming Chat Completion")
    print("=" * 60)
    
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": "I'm feeling overwhelmed with too many tasks"}
    ]
    
    start = time.time()
    resp = requests.post(f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.85,
            "max_tokens": 300,
            "stream": True
        },
        timeout=30,
        stream=True
    )
    elapsed_first = None
    full_text = ""
    chunk_count = 0
    
    for line in resp.iter_lines():
        if not line:
            continue
        line = line.decode('utf-8')
        if not line.startswith('data: '):
            continue
        data_str = line[6:]
        if data_str == '[DONE]':
            break
        try:
            data = json.loads(data_str)
            delta = data["choices"][0]["delta"]
            if "content" in delta:
                if elapsed_first is None:
                    elapsed_first = time.time() - start
                full_text += delta["content"]
                chunk_count += 1
        except:
            pass
    
    elapsed_total = time.time() - start
    
    print(f"  Status: {resp.status_code}")
    print(f"  First token: {elapsed_first:.2f}s" if elapsed_first else "  First token: N/A")
    print(f"  Total time: {elapsed_total:.1f}s")
    print(f"  Chunks: {chunk_count}")
    print(f"  Response: {full_text}")
    
    if full_text:
        print(f"  ✅ PASS")
        return True
    else:
        print(f"  ❌ FAIL")
        return False


def test_conversation_flow():
    """Test 3: Multi-turn conversation (same as ConversationStore)"""
    print("\n" + "=" * 60)
    print("TEST 3: Multi-turn Conversation")
    print("=" * 60)
    
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": "Hey!"},
    ]
    
    # Turn 1
    resp1 = requests.post(f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={"model": "gpt-4o-mini", "messages": messages, "temperature": 0.85, "max_tokens": 300},
        timeout=30
    )
    turn1 = resp1.json()["choices"][0]["message"]["content"]
    print(f"  Turn 1 (user: 'Hey!')")
    print(f"    Nudgy: {turn1}")
    
    # Turn 2
    messages.append({"role": "assistant", "content": turn1})
    messages.append({"role": "user", "content": "Can you help me get organized today?"})
    
    resp2 = requests.post(f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={"model": "gpt-4o-mini", "messages": messages, "temperature": 0.85, "max_tokens": 300},
        timeout=30
    )
    turn2 = resp2.json()["choices"][0]["message"]["content"]
    print(f"  Turn 2 (user: 'Can you help me get organized today?')")
    print(f"    Nudgy: {turn2}")
    
    if turn1 and turn2:
        print(f"  ✅ PASS")
        return True
    else:
        print(f"  ❌ FAIL")
        return False


def test_tts():
    """Test 4: OpenAI TTS with shimmer voice"""
    print("\n" + "=" * 60)
    print("TEST 4: TTS (shimmer voice)")
    print("=" * 60)
    
    text = "Oh hey! I'm Nudgy, your little penguin buddy! Ready to tackle some tasks together?"
    
    start = time.time()
    resp = requests.post(f"{BASE_URL}/audio/speech",
        headers=HEADERS,
        json={
            "model": "tts-1",
            "input": text,
            "voice": "shimmer",
            "response_format": "mp3",
            "speed": 1.0
        },
        timeout=15
    )
    elapsed = time.time() - start
    
    print(f"  Status: {resp.status_code}")
    print(f"  Time: {elapsed:.1f}s")
    print(f"  Audio size: {len(resp.content)} bytes ({len(resp.content)/1024:.1f} KB)")
    
    if resp.status_code == 200 and len(resp.content) > 1000:
        print(f"  ✅ PASS")
        return True
    else:
        print(f"  Error: {resp.text[:200] if resp.status_code != 200 else 'Audio too small'}")
        print(f"  ❌ FAIL")
        return False


def test_full_pipeline():
    """Test 5: Full pipeline — chat then TTS the response"""
    print("\n" + "=" * 60)
    print("TEST 5: Full Pipeline (Chat → TTS)")
    print("=" * 60)
    
    # Step 1: Get chat response
    start = time.time()
    resp = requests.post(f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": "What should I do today?"}
            ],
            "temperature": 0.85,
            "max_tokens": 300
        },
        timeout=30
    )
    chat_text = resp.json()["choices"][0]["message"]["content"]
    chat_time = time.time() - start
    print(f"  Chat response ({chat_time:.1f}s): {chat_text}")
    
    # Step 2: Convert to speech
    start2 = time.time()
    # Clean emojis (same as cleanForSpeech)
    clean = ''.join(c for c in chat_text if ord(c) < 0x1F000 and ord(c) not in range(0x2600, 0x27C0))
    clean = clean.replace('**', '').replace('*', '').replace('_', '')
    
    tts_resp = requests.post(f"{BASE_URL}/audio/speech",
        headers=HEADERS,
        json={
            "model": "tts-1",
            "input": clean,
            "voice": "shimmer",
            "response_format": "mp3",
            "speed": 1.0
        },
        timeout=15
    )
    tts_time = time.time() - start2
    total_time = chat_time + tts_time
    
    print(f"  TTS ({tts_time:.1f}s): {len(tts_resp.content)/1024:.1f} KB")
    print(f"  Total pipeline: {total_time:.1f}s")
    
    if resp.status_code == 200 and tts_resp.status_code == 200:
        print(f"  ✅ PASS — Full pipeline works in {total_time:.1f}s")
        return True
    else:
        print(f"  ❌ FAIL")
        return False


if __name__ == "__main__":
    print("🐧 NUDGE VOICE PIPELINE TEST")
    print(f"   API Key: ...{API_KEY[-6:]}")
    print(f"   Model: gpt-4o-mini")
    print(f"   Voice: shimmer")
    print()
    
    results = []
    results.append(("Chat Completion", test_chat()))
    results.append(("Streaming", test_streaming()))
    results.append(("Multi-turn", test_conversation_flow()))
    results.append(("TTS", test_tts()))
    results.append(("Full Pipeline", test_full_pipeline()))
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for name, passed in results:
        print(f"  {'✅' if passed else '❌'} {name}")
    
    all_pass = all(p for _, p in results)
    print(f"\n{'✅ ALL TESTS PASSED — OpenAI pipeline is working!' if all_pass else '❌ SOME TESTS FAILED'}")
