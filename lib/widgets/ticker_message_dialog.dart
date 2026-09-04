import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/ticker_message.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class TickerMessageDialog extends StatefulWidget {
  final ApiService apiService;

  const TickerMessageDialog({super.key, required this.apiService});

  @override
  State<TickerMessageDialog> createState() => _TickerMessageDialogState();
}

class _TickerMessageDialogState extends State<TickerMessageDialog> {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<TickerMessage> _messages = [];
// Available font sizes
  final List<double> _fontSizes = [12, 14, 16, 18, 20, 24, 28, 32];
  // Available icons
  final List<Map<String, String>> _availableIcons = [
    {'emoji': '📢', 'name': 'ประกาศ'},
    {'emoji': '🎉', 'name': 'ฉลอง'},
    {'emoji': '📅', 'name': 'ปฏิทิน'},
    {'emoji': '⚠️', 'name': 'เตือน'},
    {'emoji': '📚', 'name': 'หนังสือ'},
    {'emoji': '🔔', 'name': 'กระดิ่ง'},
    {'emoji': '⭐', 'name': 'ดาว'},
    {'emoji': '🔥', 'name': 'ร้อน'},
    {'emoji': '💡', 'name': 'ไอเดีย'},
    {'emoji': '✅', 'name': 'ถูกต้อง'},
    {'emoji': '❌', 'name': 'ผิด'},
    {'emoji': 'ℹ️', 'name': 'ข้อมูล'},
    {'emoji': '🏆', 'name': 'รางวัล'},
    {'emoji': '📌', 'name': 'ปักหมุด'},
    {'emoji': '🎯', 'name': 'เป้าหมาย'},
    {'emoji': '💬', 'name': 'พูดคุย'},
    {'emoji': '🔄', 'name': 'อัปเดต'},
    {'emoji': '📋', 'name': 'รายการ'},
     {'emoji': '📞', 'name': 'โทรศัพท์'}, // ✅ Telephone
    {'emoji': '📱', 'name': 'มือถือ'}, // ✅ Mobile phone
    {'emoji': '☎️', 'name': 'เบอร์โทร'}, // ✅ Phone number
    {'emoji': '📧', 'name': 'อีเมล'}, // ✅ Email
    {'emoji': '✉️', 'name': 'จดหมาย'}, // ✅ Mail
    {'emoji': '💌', 'name': 'ข้อความ'}, // ✅ Message
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await _apiService.getActiveTickerMessages();//    getAllTickerMessages();
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _addNewMessage() {
    setState(() {
      _messages.add(
        TickerMessage(icon: '', message: '', sortOrder: _messages.length,fontSize: 20),
      );
    });
  }

  void _removeMessage(int index) {
    setState(() {
      _messages.removeAt(index);
      // Update sort orders
      for (int i = 0; i < _messages.length; i++) {
        _messages[i] = _messages[i].copyWith(sortOrder: i);
      }
    });
  }

  Future<void> _handleSave() async {
    // Filter out empty messages
    final validMessages = _messages
        .where((m) => m.message.trim().isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _apiService.saveAllTickerMessages(validMessages);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccessSnackBar('บันทึกข้อความวิ่งสำเร็จ');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
        context.showErrorSnackBar(_errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 800 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxWidth: 850),
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isDesktop),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageList(isDesktop),
            ),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 45 : 38,
            height: isDesktop ? 45 : 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.campaign,
              color: AppTheme.primaryColor,
              size: isDesktop ? 24 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'จัดการข้อความวิ่ง',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'ข้อความจะแสดงบนหน้าแรกเมื่อมีข้อมูล',
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Add message button
          TextButton.icon(
            onPressed: _addNewMessage,
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: Text(
              'เพิ่ม',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 14 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDesktop) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีข้อความวิ่ง',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addNewMessage,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มข้อความ'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageCard(index, isDesktop);
      },
    );
  }

 // Update the message card widget
  Widget _buildMessageCard(int index, bool isDesktop) {
    final message = _messages[index];

    return Card(
      margin: EdgeInsets.only(bottom: isDesktop ? 12 : 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: message.message.trim().isEmpty
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Order number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Icon selector
                _buildIconSelector(index, isDesktop),
                const SizedBox(width: 8),
                // ✅ Font size selector
                _buildFontSizeSelector(index, isDesktop),
                const SizedBox(width: 8),
                // Message input
                Expanded(
                  child: TextFormField(
                    initialValue: message.message,
                    onChanged: (value) {
                      _messages[index] = message.copyWith(message: value);
                    },
                    decoration: InputDecoration(
                      hintText: 'กรอกข้อความ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: isDesktop ? 14 : 13),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                InkWell(
                  onTap: () => _removeMessage(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
            // Preview
            if (message.message.isNotEmpty || message.icon.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message.displayText,
                        style: TextStyle(
                          fontSize:
                              message.fontSize ??
                              14, // ✅ Use fontSize in preview
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
 
// ✅ Font size selector widget
  Widget _buildFontSizeSelector(int messageIndex, bool isDesktop) {
    final currentFontSize = _messages[messageIndex].fontSize ?? 14;

    return PopupMenuButton<double>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 50,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            '${currentFontSize.toInt()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
      onSelected: (size) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            fontSize: size,
          );
        });
      },
      itemBuilder: (context) => _fontSizes.map((size) {
        final isSelected = currentFontSize == size;
        return PopupMenuItem<double>(
          value: size,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Row(
              children: [
                Text(
                  '${size.toInt()} px',
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Aa',
                  style: TextStyle(fontSize: size, color: Colors.grey.shade500),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconSelector(int messageIndex, bool isDesktop) {
    final currentIcon = _messages[messageIndex].icon;

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: currentIcon.isNotEmpty
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: currentIcon.isNotEmpty
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            currentIcon.isNotEmpty ? currentIcon : '😊',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      onSelected: (icon) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            icon: icon,
          );
        });
      },
      itemBuilder: (context) => _availableIcons.map((iconData) {
        final emoji = iconData['emoji']!;
        final name = iconData['name']!;
        final isSelected = currentIcon == emoji;

        return PopupMenuItem<String>(
          value: emoji,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 14 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('ยกเลิก'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 14 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึกข้อมูล'),
            ),
          ),
        ],
      ),
    );
  }
}
