import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

/// Khung Nhập Mã OTP 6 Chữ Số Chuyên Dụng (6-Digit PIN Code Input)
/// Hỗ trợ tự động nhảy ô, xóa lùi (backspace), dán mã 6 số (Paste) và đồng bộ với TextEditingController
class OtpPinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const OtpPinInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.controller,
  });

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isInternalUpdating = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (index) {
      final node = FocusNode();
      node.onKeyEvent = (focusNode, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
            _onDigitChanged('', index - 1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
      return node;
    });

    if (widget.controller != null) {
      _syncFromExternal();
      widget.controller!.addListener(_syncFromExternal);
    }
  }

  void _syncFromExternal() {
    if (_isInternalUpdating || widget.controller == null) return;
    final text = widget.controller!.text;
    for (int i = 0; i < widget.length; i++) {
      final char = i < text.length ? text[i] : '';
      if (_controllers[i].text != char) {
        _controllers[i].text = char;
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromExternal);
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    _isInternalUpdating = true;
    try {
      // Xử lý khi dán nguyên chuỗi số từ Clipboard
      if (value.length > 1) {
        final digits = value.replaceAll(RegExp(r'\D'), '');
        for (int i = 0; i < widget.length && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        final fullCode = _currentCode;
        widget.controller?.text = fullCode;
        widget.onChanged?.call(fullCode);
        if (fullCode.length == widget.length) {
          _focusNodes.last.unfocus();
          widget.onCompleted?.call(fullCode);
        }
        return;
      }

      final code = _currentCode;
      widget.controller?.text = code;
      widget.onChanged?.call(code);

      // Tự động nhảy sang ô tiếp theo nếu đã gõ số
      if (value.isNotEmpty) {
        if (index < widget.length - 1) {
          _focusNodes[index + 1].requestFocus();
        } else {
          _focusNodes[index].unfocus();
          if (code.length == widget.length) {
            widget.onCompleted?.call(code);
          }
        }
      }
    } finally {
      _isInternalUpdating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Chiều rộng mỗi ô vuông tự co giãn mượt mà theo màn hình (tối đa 48, tối thiểu 36)
        final boxWidth = ((totalWidth - (widget.length - 1) * 8) / widget.length).clamp(36.0, 48.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            return SizedBox(
              width: boxWidth,
              height: boxWidth * 1.22,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: TextStyle(
                  fontSize: boxWidth * 0.45,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _controllers[index].text.isNotEmpty
                          ? AppColors.primary
                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2.2,
                    ),
                  ),
                ),
                onChanged: (value) => _onDigitChanged(value, index),
              ),
            );
          }),
        );
      },
    );
  }
}
