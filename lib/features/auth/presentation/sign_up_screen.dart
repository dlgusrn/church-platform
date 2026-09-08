import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_page_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _loginId.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return AuthPageScaffold(
      appBar: AppBar(title: const Text('회원가입')),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageVertical,
        AppSpacing.pageHorizontal,
        36,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정을 만들어주세요',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '가입 후 이용할 교회에 소속 신청을 진행합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: '이름'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '이름을 입력해주세요.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _loginId,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: '이메일 또는 휴대전화',
                      ),
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return '이메일 또는 휴대전화를 입력해주세요.';
                        final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(input);
                        final phone = RegExp(r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$')
                            .hasMatch(input);
                        return email || phone
                            ? null
                            : '올바른 이메일 또는 휴대전화 형식이 아닙니다.';
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _passwordDecoration('비밀번호'),
                      validator: (value) => value == null || value.isEmpty
                          ? '비밀번호를 입력해주세요.'
                          : value.length < 8
                          ? '비밀번호는 8자 이상 입력해주세요.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(state),
                      decoration: _passwordDecoration('비밀번호 확인'),
                      validator: (value) =>
                          value != _password.text ? '비밀번호가 일치하지 않습니다.' : null,
                    ),
                    if (state.registrationError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.registrationError!,
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
                        onPressed: state.isBusy ? null : () => _submit(state),
                        child: state.isBusy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('다음'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _passwordDecoration(String label) => InputDecoration(
    labelText: label,
    suffixIcon: IconButton(
      tooltip: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
  );

  Future<void> _submit(AppState state) async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final success = await state.register(
      name: _name.text,
      loginId: _loginId.text,
      password: _password.text,
    );
    if (success && mounted) Navigator.of(context).pop();
  }
}
