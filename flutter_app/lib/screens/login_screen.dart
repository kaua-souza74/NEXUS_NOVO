import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _wine = Color(0xFF4F3139);
  static const _deep = Color(0xFF2E1D24);
  static const _rose = Color(0xFF92656B);
  static const _peach = Color(0xFFD8B5A0);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _motion;
  bool _loading = false;
  bool _sendingReset = false;
  bool _passwordVisible = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível entrar. Verifique sua conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Informe seu email acima para receber o link de recuperação.';
        _notice = null;
      });
      return;
    }
    setState(() {
      _sendingReset = true;
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() =>
            _notice = 'Se o email estiver cadastrado, enviaremos um link de recuperação.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar o link agora.');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _motion.isAnimating) _motion.stop();
    if (!reduceMotion && !_motion.isAnimating) _motion.repeat(reverse: true);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_deep, _wine, _rose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) => CustomPaint(
                painter: _LoginBackdropPainter(_motion.value),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 56 : 22,
                        vertical: 24,
                      ),
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: _welcomePanel()),
                                const SizedBox(width: 54),
                                SizedBox(width: 430, child: _loginCard()),
                              ],
                            )
                          : SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 48,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _mobileWelcome(),
                                    const SizedBox(height: 26),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 460),
                                      child: _loginCard(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomePanel() => Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _brand(),
            const SizedBox(height: 76),
            const Text(
              'A inteligência\ndo seu hotel,\nem um só lugar.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                height: 1.08,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w600,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 390,
              child: Text(
                'Acompanhe espaços, dispositivos e indicadores da sua operação com clareza.',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 16,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const _SecureNote(),
          ],
        ),
      );

  Widget _mobileWelcome() => Column(
        children: [
          _brand(),
          const SizedBox(height: 26),
          const Text(
            'Bem-vindo de volta',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              letterSpacing: -.6,
              fontWeight: FontWeight.w600,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Entre para acompanhar seu hotel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
          ),
        ],
      );

  Widget _brand() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/brand/nexus_logo.png',
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              semanticLabel: 'Logo NEXUS',
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'NEXUS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ],
      );

  Widget _loginCard() => Container(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 25),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
          boxShadow: [
            BoxShadow(
              color: _deep.withValues(alpha: .24),
              blurRadius: 55,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Acesse sua conta',
                style: TextStyle(
                  color: _deep,
                  fontSize: 25,
                  letterSpacing: -.7,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Use suas credenciais para continuar.',
                style: TextStyle(color: Color(0xFF887A7D), fontSize: 13),
              ),
              const SizedBox(height: 25),
              _fieldLabel('EMAIL'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: _inputDecoration(
                  hint: 'seu@email.com',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Informe um email válido.'
                    : null,
                onChanged: (_) {
                  if (_error != null || _notice != null) {
                    setState(() {
                      _error = null;
                      _notice = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 18),
              _fieldLabel('SENHA'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: _inputDecoration(
                  hint: 'Sua senha',
                  icon: Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Informe sua senha.' : null,
                onFieldSubmitted: (_) => _signIn(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _sendingReset ? null : _sendPasswordReset,
                  style: TextButton.styleFrom(
                    foregroundColor: _rose,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: _sendingReset
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Esqueceu a senha?'),
                ),
              ),
              if (_error != null || _notice != null) ...[
                _FeedbackBox(
                  message: _error ?? _notice!,
                  isError: _error != null,
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: _wine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _wine.withValues(alpha: .65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Entrar',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(width: 9),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 19),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE9E1DE))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ACESSO SEGURO',
                        style: TextStyle(
                            color: Color(0xFF9C8F91),
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE9E1DE))),
                ],
              ),
              const SizedBox(height: 17),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 15, color: Color(0xFF8D777B)),
                  SizedBox(width: 7),
                  Text('Conexão protegida pelo Supabase Auth',
                      style: TextStyle(
                          color: Color(0xFF8D777B), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF77686B),
          fontSize: 10,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      );

  InputDecoration _inputDecoration({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0A4A5), fontSize: 13),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF9A8589)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE9E1DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE9E1DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _rose, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFB64D4E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFB64D4E), width: 1.5),
        ),
      );
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.shield_outlined,
              color: Colors.white.withValues(alpha: .78), size: 19),
          const SizedBox(width: 10),
          Text(
            'Acesso protegido e dados sempre sincronizados',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 12,
            ),
          ),
        ],
      );
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFF9E4548) : const Color(0xFF527F69);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
              size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _LoginBackdropPainter extends CustomPainter {
  const _LoginBackdropPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(phase * math.pi * 2) * 18;
    final blobPaint = Paint()..color = const Color(0xFFD8B5A0).withValues(alpha: .19);
    final rosePaint = Paint()..color = const Color(0xFFC58C87).withValues(alpha: .19);
    final glowPaint = Paint()..color = Colors.white.withValues(alpha: .035);

    canvas.drawCircle(Offset(size.width * .90, size.height * .04 + drift),
        size.width * .23, blobPaint);
    canvas.drawCircle(Offset(size.width * .99, size.height * .31 - drift),
        size.width * .13, rosePaint);
    canvas.drawCircle(Offset(size.width * .08, size.height * .92 - drift),
        size.width * .26, glowPaint);

    final path = Path()
      ..moveTo(size.width * .69, 0)
      ..cubicTo(size.width * .82, size.height * .09, size.width * .66,
          size.height * .20, size.width * .78, size.height * .27)
      ..cubicTo(size.width * .90, size.height * .35, size.width * .98,
          size.height * .22, size.width, size.height * .19)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFF0C4AD).withValues(alpha: .36),
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackdropPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
