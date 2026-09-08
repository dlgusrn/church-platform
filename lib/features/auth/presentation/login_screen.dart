import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_page_scaffold.dart';
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
    return AuthPageScaffold(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        48,
        AppSpacing.pageHorizontal,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(),
          const SizedBox(height: AppSpacing.xl),
          Text('반갑습니다', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '교회 공동체의 소식과 예배를 한곳에서 만나보세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                children: [
                  TextField(
                    controller: _loginIdController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '이메일 또는 휴대전화'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(state),
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
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
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.authError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isBusy ? null : () => _signIn(state),
                      child: state.isBusy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('로그인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
              ),
              child: const Text('처음이신가요? 회원가입'),
            ),
          ),
          if (kDebugMode && state.authRepository.accountHints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Text('개발용 Mock 계정', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '계정을 누르면 입력됩니다. 공통 비밀번호: test1234',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ...state.authRepository.accountHints.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OutlinedButton(
                  onPressed: () {
                    _loginIdController.text = account.loginId;
                    _passwordController.text = 'test1234';
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          account.description,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
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
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '교회 통합 앱',
    child: Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadii.control,
      ),
      child: const Icon(
        Icons.church_outlined,
        color: AppColors.textOnPrimary,
        size: 30,
      ),
    ),
  );
}
