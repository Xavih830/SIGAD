import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class SigadFormDialog extends StatefulWidget {
  final String title;
  final Widget child;
  final Future<void> Function() onSubmit;
  final String submitLabel;
  final String cancelLabel;
  final double maxWidth;

  const SigadFormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onSubmit,
    this.submitLabel = 'Guardar',
    this.cancelLabel = 'Cancelar',
    this.maxWidth = 500,
  });

  @override
  State<SigadFormDialog> createState() => _SigadFormDialogState();
}

class _SigadFormDialogState extends State<SigadFormDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Flexible(child: SingleChildScrollView(child: widget.child)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                    child: Text(widget.cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
