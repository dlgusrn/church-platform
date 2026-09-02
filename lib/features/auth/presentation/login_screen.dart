import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/app_theme.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.church_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 28),
            Text('반갑습니다', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('교회 공동체의 소식과 예배를 한곳에서 만나보세요.'),
            const SizedBox(height: 36),
            TextField(
              controller: _loginIdController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '이메일 또는 휴대전화'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onSubmitted: (_) => _signIn(state),
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (state.authError != null) ...[
              const SizedBox(height: 10),
              Text(
                state.authError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.isBusy ? null : () => _signIn(state),
              child: state.isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('로그인'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignUpScreen(),
                    ),
                  ),
                  child: const Text('회원가입'),
                ),
                const SizedBox(height: 14, child: VerticalDivider()),
                TextButton(
                  onPressed: () => _showNotReady(context),
                  child: const Text('비밀번호 찾기'),
                ),
              ],
            ),
            if (kDebugMode && state.authRepository.accountHints.isNotEmpty) ...[
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              const Text(
                '개발용 Mock 계정',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '계정을 누르면 입력됩니다. 공통 비밀번호: test1234',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              ...state.authRepository.accountHints.map(
                (account) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () {
                      _loginIdController.text = account.loginId;
                      _passwordController.text = 'test1234';
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: Color(0xFFE1E7E4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          account.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '소셜 로그인 준비 영역',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircleAvatar(
                  backgroundColor: AppTheme.surface,
                  child: Icon(Icons.chat_bubble_outline, color: AppTheme.ink),
                ),
                SizedBox(width: 14),
                CircleAvatar(
                  backgroundColor: AppTheme.surface,
                  child: Icon(Icons.g_mobiledata_rounded, color: AppTheme.ink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(AppState state) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await state.signIn(
      loginId: _loginIdController.text,
      password: _passwordController.text,
    );
  }

  void _showNotReady(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('실제 인증 API 연결 단계에서 제공됩니다.')));
}
