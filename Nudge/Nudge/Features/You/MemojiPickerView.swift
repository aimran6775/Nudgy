//
//  MemojiPickerView.swift
//  Nudge
//
//  Presents a text input that captures Memoji stickers from the emoji keyboard.
//  When the user navigates to the Memoji section of the emoji keyboard and
//  taps a sticker, it's inserted as an NSTextAttachment image into the text view.
//  We extract that image and pass it back as a UIImage.
//
//  Usage: Present as a sheet, bind to an onMemojiSelected closure.
//

import SwiftUI
import UIKit

// MARK: - Memoji Picker Sheet

struct MemojiPickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    var onMemojiSelected: (UIImage) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var showHint = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.spacingLG) {
                    Spacer()
                    
                    // Preview of selected Memoji
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(DesignTokens.accentActive.opacity(0.4), lineWidth: 2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        
                        Text(String(localized: "Looking good! 🐧"))
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        // Hint illustration
                        VStack(spacing: DesignTokens.spacingMD) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 56))
                                .foregroundStyle(DesignTokens.accentActive.opacity(0.4))
                            
                            Text(String(localized: "Tap a Memoji sticker below"))
                                .font(AppTheme.headline)
                                .foregroundStyle(DesignTokens.textPrimary)
                            
                            Text(String(localized: "Open the emoji keyboard → swipe to Memoji stickers → tap the one you want"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignTokens.spacingXXL)
                        }
                    }
                    
                    Spacer()
                    
                    // Hidden text view that captures the Memoji sticker
                    MemojiCaptureField { image in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            capturedImage = image
                        }
                    }
                    .frame(height: 44)
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "Choose Memoji"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        if let image = capturedImage {
                            onMemojiSelected(image)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(capturedImage != nil ? DesignTokens.accentActive : DesignTokens.textTertiary)
                    .disabled(capturedImage == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - UIKit Text View for Memoji Capture

/// A UITextView wrapped in UIViewRepresentable that auto-shows the emoji keyboard
/// and captures any Memoji sticker inserted as an NSTextAttachment image.
struct MemojiCaptureField: UIViewRepresentable {
    
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        textView.font = UIFont.systemFont(ofSize: 48)
        textView.textAlignment = .center
        textView.backgroundColor = UIColor(white: 1, alpha: 0.05)
        textView.layer.cornerRadius = 12
        textView.textColor = .white
        textView.tintColor = UIColor(DesignTokens.accentActive)
        textView.keyboardAppearance = .dark
        textView.returnKeyType = .done
        
        // Placeholder
        textView.text = ""
        let placeholder = NSAttributedString(
            string: String(localized: "Tap here, then pick a Memoji"),
            attributes: [
                .foregroundColor: UIColor(white: 1, alpha: 0.3),
                .font: UIFont.systemFont(ofSize: 15)
            ]
        )
        // Store placeholder for coordinator
        context.coordinator.placeholder = placeholder
        context.coordinator.textView = textView
        
        // Show placeholder initially
        textView.attributedText = placeholder
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var onImageCaptured: (UIImage) -> Void
        var placeholder: NSAttributedString?
        weak var textView: UITextView?
        private var isShowingPlaceholder = true
        
        init(onImageCaptured: @escaping (UIImage) -> Void) {
            self.onImageCaptured = onImageCaptured
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if isShowingPlaceholder {
                textView.text = ""
                textView.textColor = .white
                isShowingPlaceholder = false
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty, let placeholder {
                textView.attributedText = placeholder
                isShowingPlaceholder = true
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Check for image attachments in the attributed text
            textView.attributedText.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { value, _, stop in
                if let attachment = value as? NSTextAttachment {
                    // Try to get the image from the attachment
                    var image: UIImage?
                    
                    if let attachmentImage = attachment.image {
                        image = attachmentImage
                    } else if let data = attachment.fileWrapper?.regularFileContents {
                        image = UIImage(data: data)
                    } else if let cgImage = attachment.image(
                        forBounds: CGRect(origin: .zero, size: CGSize(width: 512, height: 512)),
                        textContainer: nil,
                        characterIndex: 0
                    ) {
                        image = cgImage
                    }
                    
                    if let image {
                        // Render at a nice size for avatar use
                        let rendered = self.renderAtSize(image, size: CGSize(width: 256, height: 256))
                        DispatchQueue.main.async {
                            self.onImageCaptured(rendered)
                        }
                        stop.pointee = true
                    }
                }
            }
            
            // Also check UIPasteboard for recently pasted sticker images
            if let pasteImage = UIPasteboard.general.image {
                let rendered = renderAtSize(pasteImage, size: CGSize(width: 256, height: 256))
                DispatchQueue.main.async {
                    self.onImageCaptured(rendered)
                }
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                textView.resignFirstResponder()
                return false
            }
            return true
        }
        
        /// Render an image at a specific size for clean avatar display.
        private func renderAtSize(_ image: UIImage, size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MemojiPickerView { image in
        print("Selected Memoji: \(image.size)")
    }
}
