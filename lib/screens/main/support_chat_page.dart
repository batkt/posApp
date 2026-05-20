import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:record/record.dart' as record;
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/auth_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_snackbar.dart';
import '../../services/pos_settings_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  bool _isLoading = true;
  String? _chatId;
  List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  String? _guestId;
  String? _displayName;
  String? _baiguullagaName;
  String? _ajiltniiNer;

  List<dynamic> _rootChoices = [];
  List<dynamic> _currentChoices = [];
  bool _humanMode = false;
  bool _isOperatorLoading = false;
  String _restartLabel = 'Эхлэл рүү буцах';

  bool _isRecording = false;
  int _recordingTime = 0;
  record.AudioRecorder? _audioRecorder;
  Timer? _recordingTimer;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = record.AudioRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder!.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder!.start(
          const record.RecordConfig(encoder: record.AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingTime = 0;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingTime++;
          });
        });
      } else {
        showAppSnackBar(context, 'Микрофон ашиглах зөвшөөрөл шаардлагатай.', variant: AppSnackVariant.error);
      }
    } catch (e) {
      showAppSnackBar(context, 'Бичлэг эхлүүлэхэд алдаа гарлаа: $e', variant: AppSnackVariant.error);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await _uploadAndSendFile(file, 'audio', duration: _recordingTime);
        }
      }
    } catch (e) {
      showAppSnackBar(context, 'Бичлэг хадгалахад алдаа гарлаа: $e', variant: AppSnackVariant.error);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _recordingTime = 0;
      });
    } catch (_) {}
  }

  Future<void> _uploadAndSendFile(File file, String fileType, {int? duration}) async {
    if (_chatId == null || _guestId == null) return;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/upload'),
      );
      
      final length = await file.length();
      int byteCount = 0;
      final stream = http.ByteStream(file.openRead().transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            byteCount += data.length;
            if (mounted) {
              setState(() {
                _uploadProgress = byteCount / length;
              });
            }
            sink.add(data);
          },
        ),
      ));

      request.files.add(
        http.MultipartFile('file', stream, length, filename: file.path.split('/').last),
      );
      request.fields['fileType'] = fileType;

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true) {
          final fileUrl = resData['fileUrl'];
          
          final msgResponse = await http.post(
            Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations/$_chatId/messages'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': '',
              'guestId': _guestId,
              'displayName': _displayName,
              'project': 'posapp',
              'baiguullagaName': _baiguullagaName,
              'ajiltniiNer': _ajiltniiNer,
              'fileUrl': fileUrl,
              'fileType': fileType,
              'duration': duration,
            }),
          );

          if (msgResponse.statusCode == 200 || msgResponse.statusCode == 201) {
            _fetchMessages(silent: true);
          }
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      showAppSnackBar(context, 'Файл илгээхэд алдаа гарлаа: $e', variant: AppSnackVariant.error);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    final picker = image_picker.ImagePicker();
    
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Файл хавсаргах',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionItem(
                    icon: Icons.image_rounded,
                    label: 'Зураг сонгох',
                    color: Colors.blue,
                    onTap: () => Navigator.pop(context, 'image'),
                  ),
                  _buildOptionItem(
                    icon: Icons.video_collection_rounded,
                    label: 'Видео сонгох',
                    color: Colors.purple,
                    onTap: () => Navigator.pop(context, 'video'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (selection == null) return;

    if (selection == 'image') {
      final picked = await picker.pickImage(source: image_picker.ImageSource.gallery);
      if (picked != null) {
        await _uploadAndSendFile(File(picked.path), 'image');
      }
    } else if (selection == 'video') {
      final picked = await picker.pickVideo(source: image_picker.ImageSource.gallery);
      if (picked != null) {
        await _uploadAndSendFile(File(picked.path), 'video');
      }
    }
  }

  Widget _buildOptionItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _initializeChat() async {
    try {
      final auth = context.read<AuthModel>();
      final user = auth.currentUser;
      final session = auth.posSession;

      final ajiltan = session?.ajiltan;
      final employeeId = ajiltan?['_id']?.toString() ?? ajiltan?['id']?.toString() ?? user?.id ?? 'unknown';
      _guestId = 'employee_$employeeId';
      _displayName = user?.name ?? ajiltan?['ner']?.toString() ?? 'Ажилтан';
      _ajiltniiNer = _displayName;
      
      final orgId = session?.baiguullagiinId ?? 'POS';
      String orgName = orgId;
      try {
        final org = await posSettingsService.fetchBaiguullaga(orgId);
        if (org != null && org['ner'] != null) {
          orgName = org['ner'].toString();
        }
      } catch (_) {}
      _baiguullagaName = orgName;

      // 1. Fetch chat config (chatbot choices)
      final configResponse = await http.get(Uri.parse('https://admin.zevtabs.mn/api/v1/chat/config?project=posapp'));
      if (configResponse.statusCode == 200) {
        final configData = jsonDecode(configResponse.body)['data'];
        if (configData != null) {
          _rootChoices = configData['rootChoices'] as List<dynamic>? ?? [];
          _currentChoices = List<dynamic>.from(_rootChoices);
          _restartLabel = configData['restartLabel'] ?? 'Эхлэл рүү буцах';
        }
      }

      // 2. Fetch or create conversation
      final response = await http.post(
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'guestId': _guestId,
          'displayName': _displayName,
          'project': 'posapp',
          'baiguullagaName': _baiguullagaName,
          'ajiltniiNer': _ajiltniiNer,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final convData = resData['data'];
        if (convData != null) {
          _chatId = convData['id'] ?? convData['_id'];
          _humanMode = convData['humanMode'] == true;
          await _fetchMessages();
        }
      }

      setState(() => _isLoading = false);
      _scrollToBottom();

      // Start periodic message polling every 3 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted && _chatId != null) {
          _fetchMessages(silent: true);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppSnackBar(context, 'Чат холбоход алдаа гарлаа: $e', variant: AppSnackVariant.error);
      }
    }
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_chatId == null || _guestId == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations/$_chatId/messages?guestId=$_guestId'),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final list = resData['data'] as List<dynamic>? ?? [];
        final lastOldId = _messages.isNotEmpty ? _messages.last['id'] : null;
        final lastNewId = list.isNotEmpty ? list.last['id'] : null;
        final hasNew = list.length != _messages.length || lastOldId != lastNewId;

        if (mounted) {
          setState(() {
            _messages = list;
          });
          if (hasNew) {
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        showAppSnackBar(context, 'Мессеж татахад алдаа гарлаа', variant: AppSnackVariant.error);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _guestId == null) return;

    final tempMsg = {
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'role': 'user',
      'isTemp': true,
    };

    setState(() {
      _messages.add(tempMsg);
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations/$_chatId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'guestId': _guestId,
          'displayName': _displayName,
          'project': 'posapp',
          'baiguullagaName': _baiguullagaName,
          'ajiltniiNer': _ajiltniiNer,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchMessages(silent: true);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Мессеж илгээхэд алдаа гарлаа: $e', variant: AppSnackVariant.error);
      }
    }
  }

  Future<void> _sendChoice(dynamic choice) async {
    final text = choice['label']?.toString() ?? '';
    if (text.isEmpty || _chatId == null || _guestId == null) return;

    final tempMsg = {
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'role': 'user',
      'isTemp': true,
    };

    setState(() {
      _messages.add(tempMsg);
      final subChoices = choice['choices'] as List<dynamic>? ?? [];
      if (subChoices.isNotEmpty) {
        _currentChoices = subChoices;
      } else {
        _currentChoices = List<dynamic>.from(_rootChoices);
      }
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations/$_chatId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'guestId': _guestId,
          'displayName': _displayName,
          'project': 'posapp',
          'baiguullagaName': _baiguullagaName,
          'ajiltniiNer': _ajiltniiNer,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchMessages(silent: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Мессеж илгээхэд алдаа гарлаа: $e', variant: AppSnackVariant.error);
      }
    }
  }

  Future<void> _connectToOperator() async {
    if (_chatId == null || _guestId == null) return;
    setState(() => _isOperatorLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://admin.zevtabs.mn/api/v1/chat/conversations/$_chatId/operator'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'guestId': _guestId}),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body)['data'];
        if (resData != null && resData['conversation'] != null) {
          setState(() {
            _humanMode = resData['conversation']['humanMode'] == true;
          });
        }
      }
      _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Оператортой холбоход алдаа гарлаа', variant: AppSnackVariant.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isOperatorLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChoicesContainer(ColorScheme colorScheme, TextTheme textTheme) {
    if (_humanMode || _currentChoices.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ..._currentChoices.map((c) {
              final label = c['label']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: colorScheme.primary.withOpacity(0.06),
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _sendChoice(c),
                ),
              );
            }),
            if (_currentChoices != _rootChoices)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(Icons.refresh_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                  label: Text(
                    _restartLabel,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    setState(() {
                      _currentChoices = List<dynamic>.from(_rootChoices);
                    });
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: _isOperatorLoading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                      )
                    : const Icon(Icons.support_agent_rounded, size: 14, color: Colors.green),
                label: const Text(
                  'Оператортой холбох',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.green.withOpacity(0.06),
                side: BorderSide(color: Colors.green.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: _isOperatorLoading ? null : _connectToOperator,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тусламж & Дэмжлэг'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 64,
                                color: colorScheme.primary.withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Мессеж байхгүй байна',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['role'] == 'user';
                            // Find last HUMAN AGENT message index (not bot)
                            int lastAgentIdx = -1;
                            int lastUserIdx = -1;
                            for (int i = _messages.length - 1; i >= 0; i--) {
                              if (_messages[i]['role'] == 'agent' && lastAgentIdx == -1) {
                                lastAgentIdx = i;
                              }
                              if (_messages[i]['role'] == 'user' && lastUserIdx == -1) {
                                lastUserIdx = i;
                              }
                            }
                            final isLastAgentMsg = (index == lastAgentIdx);
                            final isLastUserMsg = (index == lastUserIdx);
                            return _buildMessageBubble(
                              msg,
                              isMe,
                              colorScheme,
                              theme,
                              isLastAgentMsg: isLastAgentMsg,
                              isLastUserMsg: isLastUserMsg,
                            );
                          },
                        ),
                ),
                _buildChoicesContainer(colorScheme, textTheme),
                _buildMessageInput(colorScheme),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(
    dynamic msg, 
    bool isMe, 
    ColorScheme colorScheme, 
    ThemeData theme, {
    bool isLastAgentMsg = false,
    bool isLastUserMsg = false,
  }) {
    final text = msg['text'] ?? '';
    final dateStr = msg['createdAt'];
    final fileUrl = msg['fileUrl'];
    final fileType = msg['fileType'];
    final duration = msg['duration'];
    final readByGuest = msg['readByGuest'] == true;
    final readByGuestAt = msg['readByGuestAt'];
    final readByAgent = msg['readByAgent'] == true;
    final readByAgentAt = msg['readByAgentAt'];

    String timeStr = '';
    if (dateStr != null) {
      try {
        final parsed = DateTime.parse(dateStr).toLocal();
        timeStr = DateFormat('HH:mm').format(parsed);
      } catch (_) {}
    }

    String? seenTimeStr;
    if (!isMe && readByGuestAt != null) {
      try {
        seenTimeStr = DateFormat('HH:mm').format(DateTime.parse(readByGuestAt.toString()).toLocal());
      } catch (_) {}
    } else if (isMe && readByAgentAt != null) {
      try {
        seenTimeStr = DateFormat('HH:mm').format(DateTime.parse(readByAgentAt.toString()).toLocal());
      } catch (_) {}
    }

    // Pure image/video with no text → render without bubble background
    final isMediaOnly = fileUrl != null && (fileType == 'image' || fileType == 'video') && text.isEmpty;

    Widget buildContent() {
      if (isMediaOnly) {
        if (fileType == 'image') {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    body: Center(child: Image.network('https://admin.zevtabs.mn/api/file?path=$fileUrl')),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                'https://admin.zevtabs.mn/api/file?path=$fileUrl',
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : Container(
                        width: 220,
                        height: 160,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ChatVideoPlayer(url: 'https://admin.zevtabs.mn/api/file?path=$fileUrl'),
          );
        }
      }

      // Normal bubble for text / audio / text+media
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty) ...[
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMe ? Colors.white : colorScheme.onSurface,
                ),
              ),
              if (fileUrl != null) const SizedBox(height: 8),
            ],
            if (fileUrl != null) ...[
              if (fileType == 'image')
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                          body: Center(child: Image.network('https://admin.zevtabs.mn/api/file?path=$fileUrl')),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network('https://admin.zevtabs.mn/api/file?path=$fileUrl', width: 200, fit: BoxFit.fitWidth),
                  ),
                )
              else if (fileType == 'video')
                ChatVideoPlayer(url: 'https://admin.zevtabs.mn/api/file?path=$fileUrl')
              else if (fileType == 'audio')
                VoicePlayBubble(fileUrl: fileUrl, duration: duration, isMe: isMe),
            ],
          ],
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          buildContent(),
          if (timeStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
              child: Text(
                timeStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          // Show "Харсан HH:mm" under last agent/bot message or last user message
          if ((!isMe && isLastAgentMsg && readByGuest) || (isMe && isLastUserMsg && readByAgent))
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.done_all_rounded, size: 12, color: Colors.blue.shade400),
                  const SizedBox(width: 3),
                  Text(
                    seenTimeStr != null ? 'Харсан · $seenTimeStr' : 'Харсан',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade400, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Дуу хурааж байна... ${_recordingTime ~/ 60}:${(_recordingTime % 60).toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            TextButton(
              onPressed: _cancelRecording,
              child: Text('Болих', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _stopRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Илгээх', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isUploading ? null : _pickAndUploadFile,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isUploading,
              decoration: InputDecoration(
                hintText: _isUploading ? 'Файл хуулж байна... ${(_uploadProgress * 100).toInt()}%' : 'Мессеж бичих...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.mic_none_rounded, color: Colors.red.shade600, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isUploading ? null : _startRecording,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isUploading ? null : _sendMessage,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class VoicePlayBubble extends StatefulWidget {
  final String fileUrl;
  final dynamic duration;
  final bool isMe;

  const VoicePlayBubble({
    super.key,
    required this.fileUrl,
    this.duration,
    required this.isMe,
  });

  @override
  State<VoicePlayBubble> createState() => _VoicePlayBubbleState();
}

class _VoicePlayBubbleState extends State<VoicePlayBubble> {
  late audioplayers.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0.0;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = audioplayers.AudioPlayer();
    
    if (widget.duration != null) {
      _duration = Duration(seconds: (widget.duration as num).round());
    }

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == audioplayers.PlayerState.playing;
        });
      }
    });

    _durSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });

    _posSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = pos;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final fullUrl = 'https://admin.zevtabs.mn/api/file?path=${widget.fileUrl}';
      await _audioPlayer.play(audioplayers.UrlSource(fullUrl));
    }
  }

  String _formatDuration(Duration d) {
    final sec = d.inSeconds % 60;
    final min = d.inMinutes;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeColor = widget.isMe ? Colors.white : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      width: 200,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              size: 36,
              color: themeColor,
            ),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: themeColor,
                    inactiveTrackColor: themeColor.withOpacity(0.25),
                    thumbColor: themeColor,
                    overlayColor: themeColor.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: _isDragging
                        ? _dragValue
                        : (_duration.inMilliseconds > 0
                            ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0),
                    onChangeStart: (val) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = val;
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChangeEnd: (val) async {
                      final seekTo = Duration(milliseconds: (val * _duration.inMilliseconds).round());
                      await _audioPlayer.seek(seekTo);
                      setState(() {
                        _isDragging = false;
                        _position = seekTo;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(color: themeColor.withOpacity(0.8), fontSize: 10),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(color: themeColor.withOpacity(0.8), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatVideoPlayer extends StatefulWidget {
  final String url;
  const ChatVideoPlayer({super.key, required this.url});

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.url), play: false);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Video(
          controller: controller,
          onEnterFullscreen: () async {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
            });
          },
          onExitFullscreen: () async {
            await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          },
        ),
      ),
    );
  }
}

