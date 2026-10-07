import 'dart:async';

import 'package:flutter/material.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';

class LiveChatPageWidget extends StatefulWidget {
  const LiveChatPageWidget({super.key});

  @override
  State<LiveChatPageWidget> createState() => _LiveChatPageWidgetState();
}

class _LiveChatPageWidgetState extends State<LiveChatPageWidget> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  List<Map<String, dynamic>> _tickets = [];
  bool _sending = false;
  String? _sendingReplyTicketId;
  bool _loadingTickets = true;
  String? _ticketsError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loadingTickets && !_sending && _sendingReplyTicketId == null) {
        _loadTickets(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subjectController.dispose();
    _messageController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loadingTickets = true;
        _ticketsError = null;
      });
    }
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/support/tickets',
      );
      final rows = response['data'];
      if (rows is! List) {
        throw const FormatException('Invalid support enquiry response');
      }
      if (!mounted) return;
      setState(() {
        _tickets = rows.whereType<Map<String, dynamic>>().toList();
        _loadingTickets = false;
        _ticketsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketsError = error.toString();
        _loadingTickets = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a subject and message')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.request(
        method: 'POST',
        path: '/support/tickets',
        body: {'subject': subject, 'message': message},
      );
      _subjectController.clear();
      _messageController.clear();
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Your enquiry has been sent to support.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send enquiry: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  TextEditingController _replyControllerFor(String ticketId) =>
      _replyControllers.putIfAbsent(ticketId, TextEditingController.new);

  Future<void> _replyToTicket(String ticketId) async {
    final controller = _replyControllerFor(ticketId);
    final message = controller.text.trim();
    if (message.isEmpty) return;

    setState(() => _sendingReplyTicketId = ticketId);
    try {
      await ApiService.request(
        method: 'POST',
        path: '/support/tickets/$ticketId/reply',
        body: {'message': message},
      );
      controller.clear();
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your reply has been sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reply: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReplyTicketId = null);
    }
  }

  String _value(dynamic value, [String fallback = '']) =>
      value is String && value.isNotEmpty ? value : fallback;

  String _dateTimeValue(dynamic value) {
    if (value is! String) return '';
    final dateTime = DateTime.tryParse(value);
    return dateTime == null
        ? ''
        : dateTime.toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        title: const Text('Live Chat'),
        actions: [
          IconButton(
            tooltip: 'Refresh enquiries',
            onPressed: _loadingTickets ? null : _loadTickets,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: theme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send an enquiry to our support team. You can see replies here.',
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          TextField(
            controller: _messageController,
            minLines: 4,
            maxLines: 8,
            maxLength: 5000,
            decoration: InputDecoration(
              labelText: 'Your enquiry',
              hintText: 'Type your message here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send to Support'),
            ),
          ),
          const SizedBox(height: 24),
          Text('My enquiries', style: theme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingTickets)
            const Center(child: CircularProgressIndicator())
          else if (_ticketsError != null && _tickets.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not load your enquiries: $_ticketsError'),
                TextButton(
                  onPressed: _loadTickets,
                  child: const Text('Try again'),
                ),
              ],
            )
          else if (_tickets.isEmpty)
            const Text('You have not sent any enquiries yet.')
          else ...[
            if (_ticketsError != null)
              TextButton(
                onPressed: _loadTickets,
                child: Text('Could not refresh enquiries: $_ticketsError'),
              ),
            ..._tickets.map((ticket) {
              final replies = ticket['support_messages'];
              return Card(
                child: ExpansionTile(
                  title: Text(_value(ticket['subject'], 'Enquiry')),
                  subtitle: Text(_value(ticket['status'], 'open')),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'You',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text([
                        _dateTimeValue(ticket['created_at']),
                        _value(ticket['message']),
                      ].where((part) => part.isNotEmpty).join('\n')),
                      dense: true,
                    ),
                    if (replies is List)
                      ...replies.whereType<Map<String, dynamic>>().map(
                        (reply) {
                          final sender = reply['users'];
                          final senderRole = sender is Map<String, dynamic>
                              ? _value(sender['role']).toLowerCase()
                              : '';
                          final senderName = sender is Map<String, dynamic>
                              ? [
                                  _value(sender['first_name']),
                                  _value(sender['last_name']),
                                ].where((part) => part.isNotEmpty).join(' ')
                              : '';
                          final senderLabel = senderRole.contains('admin')
                              ? 'Support${senderName.isEmpty ? '' : ' · $senderName'}'
                              : 'You';
                          final sentAt = _dateTimeValue(reply['created_at']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_value(reply['message'])),
                            subtitle: Text([
                              senderLabel,
                              sentAt,
                            ].where((part) => part.isNotEmpty).join(' · ')),
                          );
                        },
                      ),
                    const Divider(height: 24),
                    TextField(
                      controller: _replyControllerFor(
                        _value(ticket['id']),
                      ),
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'Reply to support',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _value(ticket['id']).isEmpty ||
                                _sendingReplyTicketId == _value(ticket['id'])
                            ? null
                            : () => _replyToTicket(_value(ticket['id'])),
                        icon: _sendingReplyTicketId == _value(ticket['id'])
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Send reply'),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
