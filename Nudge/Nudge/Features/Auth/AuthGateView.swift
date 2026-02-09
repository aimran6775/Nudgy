import SwiftUI
import AuthenticationServices

// MARK: - Auth Mode

private enum AuthMode: Equatable {
    case landing
    case signUp
    case signIn
}

// MARK: - Auth Gate

struct AuthGateView: View {

    @Environment(AuthSession.self) private var auth

    @State private var mode: AuthMode = .landing
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Ambient background
            ambientBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.spacingXL) {
                    Spacer().frame(height: 60)

                    // Header
                    VStack(spacing: DesignTokens.spacingSM) {
                        Text("🐧")
                            .font(.system(size: 56))
                            .shadow(color: Color(hex: "0A84FF").opacity(0.4), radius: 20, y: 6)

                        Text(headerTitle)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(headerSubtitle)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.spacingXL)
                    }

                    // Glass card
                    glassCard {
                        cardContent
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)

                    Spacer().frame(height: 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
    }

    // MARK: - Header Text

    private var headerTitle: String {
        switch mode {
        case .landing: return String(localized: "Welcome back")
        case .signUp:  return String(localized: "Create Account")
        case .signIn:  return String(localized: "Sign In")
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .landing: return String(localized: "Pick how you'd like to continue")
        case .signUp:  return String(localized: "Start your journey with Nudgy")
        case .signIn:  return String(localized: "Good to see you again")
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            Color.black

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "0A84FF").opacity(0.2), .clear],
                        center: .center, startRadius: 0, endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -80, y: -250)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "5E5CE6").opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 120, y: 350)
                .blur(radius: 60)
        }
    }

    // MARK: - Glass Card

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: DesignTokens.spacingMD) {
            content()
        }
        .padding(DesignTokens.spacingXL)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Card Content Router

    @ViewBuilder
    private var cardContent: some View {
        switch auth.state {
        case .checking:
            ProgressView()
                .tint(.white)
                .padding(.vertical, DesignTokens.spacingXL)

        case .signedOut:
            switch mode {
            case .landing:  landingContent
            case .signUp:   signUpContent
            case .signIn:   signInContent
            }

        case .signedIn:
            ProgressView()
                .tint(.white)
                .padding(.vertical, DesignTokens.spacingXL)
        }
    }

    // MARK: - Landing

    private var landingContent: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            SignInWithAppleButton(
                .continue,
                onRequest: { $0.requestedScopes = [.fullName, .email] },
                onCompletion: { result in
                    if case .success(let auth) = result,
                       let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                        Task { await self.auth.completeAppleSignIn(with: cred) }
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            orDivider

            glassButton(title: String(localized: "Sign up with Email"), icon: "envelope.fill") {
                withAnimation { mode = .signUp }
            }

            Button {
                withAnimation { mode = .signIn }
            } label: {
                Text(String(localized: "Already have an account? **Sign in**"))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Sign Up

    private var signUpContent: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            VStack(spacing: 10) {
                GlassTextField(placeholder: String(localized: "Name"), text: $displayName, icon: "person.fill", contentType: .name)
                GlassTextField(placeholder: String(localized: "Email"), text: $email, icon: "envelope.fill", contentType: .emailAddress, keyboard: .emailAddress)
                    .textInputAutocapitalization(.never)
                GlassSecureField(placeholder: String(localized: "Password (6+ chars)"), text: $password, icon: "lock.fill")
                GlassSecureField(placeholder: String(localized: "Confirm Password"), text: $confirmPassword, icon: "lock.fill")
            }

            errorBanner

            accentButton(title: String(localized: "Create Account"), enabled: signUpValid, loading: isLoading) {
                performSignUp()
            }

            switchLink(String(localized: "Already have an account? **Sign in**")) { mode = .signIn }
            backLink
        }
    }

    // MARK: - Sign In

    private var signInContent: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            VStack(spacing: 10) {
                GlassTextField(placeholder: String(localized: "Email"), text: $email, icon: "envelope.fill", contentType: .emailAddress, keyboard: .emailAddress)
                    .textInputAutocapitalization(.never)
                GlassSecureField(placeholder: String(localized: "Password"), text: $password, icon: "lock.fill")
            }

            errorBanner

            accentButton(title: String(localized: "Sign In"), enabled: signInValid, loading: isLoading) {
                performSignIn()
            }

            switchLink(String(localized: "Don't have an account? **Sign up**")) { mode = .signUp }
            backLink
        }
    }

    // MARK: - Shared Pieces

    private var orDivider: some View {
        HStack {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
            Text(String(localized: "or"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }

    private func glassButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private func accentButton(title: String, enabled: Bool, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        enabled
                            ? LinearGradient(colors: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .shadow(color: enabled ? Color(hex: "0A84FF").opacity(0.3) : .clear, radius: 16, y: 6)
        }
        .disabled(!enabled || loading)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "FF453A"))
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    private func switchLink(_ text: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { clearForm(); action() }
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var backLink: some View {
        Button {
            withAnimation { clearForm(); mode = .landing }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(String(localized: "Back"))
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Validation

    private var signUpValid: Bool { !email.isEmpty && password.count >= 6 && password == confirmPassword }
    private var signInValid: Bool { !email.isEmpty && !password.isEmpty }

    // MARK: - Actions

    private func performSignUp() {
        errorMessage = nil
        guard password == confirmPassword else {
            errorMessage = String(localized: "Passwords don't match.")
            return
        }
        isLoading = true
        Task {
            do { try await auth.signUpWithEmail(email, password: password, name: displayName) }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    private func performSignIn() {
        errorMessage = nil
        isLoading = true
        Task {
            do { try await auth.signInWithEmail(email, password: password) }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    private func clearForm() {
        email = ""; password = ""; confirmPassword = ""; displayName = ""; errorMessage = nil
    }
}

// MARK: - Glass Text Field

private struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Glass Secure Field

private struct GlassSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 20)
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(.white)

            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
