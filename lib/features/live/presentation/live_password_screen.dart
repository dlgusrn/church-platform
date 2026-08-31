import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/domain/home_models.dart';
import '../data/live_access_service.dart';
import 'live_player_screen.dart';

class LivePasswordScreen extends StatefulWidget {
  const LivePasswordScreen({
    super.key,
    required this.live,
    required this.accessService,
  });
  final LiveBroadcast live;
  final LiveAccessService accessService;
  @override
  State<LivePasswordScreen> createState() => _LivePasswordScreenState();
}

class _LivePasswordScreenState extends State<LivePasswordScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EFEB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 26),
              Text('생방송 입장', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                '생방송 시청을 위해\n방송 비밀번호를 입력해주세요.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 34),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '● ● ● ● ● ●',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 3,
                    color: Color(0xFFB4BCB9),
                  ),
                  errorText: _error,
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('방송 입장'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final grant = await widget.accessService.verifyPassword(
      liveId: widget.live.id,
      password: _controller.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (grant == null) {
      setState(() => _error = '방송 비밀번호가 올바르지 않습니다.');
      return;
    }
    await LivePlayerScreen.open(
      context,
      live: widget.live,
      grant: grant,
      replace: true,
    );
  }
}
