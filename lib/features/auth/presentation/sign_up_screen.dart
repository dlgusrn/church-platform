import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입'), backgroundColor: Colors.white),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            children: [
              Text(
                '계정을 만들어주세요',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                '가입 후 이용할 교회에 소속 신청을 진행합니다.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '이름을 입력해주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _loginId,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이메일 또는 휴대전화'),
                validator: (value) {
                  final input = value?.trim() ?? '';
                  if (input.isEmpty) return '이메일 또는 휴대전화를 입력해주세요.';
                  final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(input);
                  final phone = RegExp(r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$')
                      .hasMatch(input);
                  return email || phone ? null : '올바른 이메일 또는 휴대전화 형식이 아닙니다.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
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
                validator: (value) => value == null || value.isEmpty
                    ? '비밀번호를 입력해주세요.'
                    : value.length < 8
                    ? '비밀번호는 8자 이상 입력해주세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmation,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(state),
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
                validator: (value) =>
                    value != _password.text ? '비밀번호가 일치하지 않습니다.' : null,
              ),
              if (state.registrationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.registrationError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: state.isBusy ? null : () => _submit(state),
                child: state.isBusy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
