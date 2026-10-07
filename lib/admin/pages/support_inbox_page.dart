import 'dart:async';

import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

class SupportInboxPage extends StatefulWidget {
  const SupportInboxPage({super.key});

  @override
  State<SupportInboxPage> createState() => _SupportInboxPageState();
}

class _SupportInboxPageState extends State<SupportInboxPage> {
  List<Map<String, dynamic>> _tickets = [];
  final Map<String, TextEditingController> _replyControllers = {};
  bool _loading = true;
  String? _error;
  String? _sendingTicketId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loading && _sendingTicketId == null) {
        _loadTickets(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await AdminApiService.getSupportTickets();
      final rows = result['data'];
      if (rows is! List) {
        throw const FormatException('Invalid support ticket response');
      }
      if (!mounted) return;
      setState(() {
        _tickets = rows.whereType<Map<String, dynamic>>().toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  TextEditingController _controllerFor(String ticketId) =>
      _replyControllers.putIfAbsent(ticketId, TextEditingController.new);

  Future<void> _sendReply(String ticketId) async {
    final controller = _controllerFor(ticketId);
    final message = controller.text.trim();
    if (message.isEmpty) return;

    setState(() => _sendingTicketId = ticketId);
    try {
      await AdminApiService.replyToSupportTicket(ticketId, message);
      controller.clear();
      await _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent to the user.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reply: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTicketId = null);
    }
  }

  String _stringValue(dynamic value, [String fallback = '']) =>
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Support enquiries'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh enquiries',
            onPressed: _loading ? null : _loadTickets,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
                  && _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadTickets,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : _tickets.isEmpty
                  ? const Center(child: Text('No support enquiries yet.'))
                  : RefreshIndicator(
                      onRefresh: _loadTickets,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length + (_error == null ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (_error != null && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Could not refresh support enquiries: $_error',
                              ),
                            );
                          }
                          final ticketIndex =
                              index - (_error == null ? 0 : 1);
                          final ticket = _tickets[ticketIndex];
                          final id = _stringValue(ticket['id']);
                          final user =
                              ticket['users_support_tickets_user_idTousers'];
                          final messages = ticket['support_messages'];
                          final customer = user is Map<String, dynamic>
                              ? [
                                  _stringValue(user['first_name']),
                                  _stringValue(user['last_name']),
                                ].where((part) => part.isNotEmpty).join(' ')
                              : '';
                          final customerEmail = user is Map<String, dynamic>
                              ? _stringValue(user['email'])
                              : '';
                          final customerPhone = user is Map<String, dynamic>
                              ? _stringValue(user['phone'])
                              : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              key: PageStorageKey<String>('support-$id'),
                              title: Text(
                                _stringValue(ticket['subject'], 'Enquiry'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${customer.isEmpty ? 'User' : customer}'
                                '  ·  ${_stringValue(ticket['status'], 'open')}',
                              ),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'From ${customer.isEmpty ? 'User' : customer}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text([
                                    if (customerEmail.isNotEmpty) customerEmail,
                                    if (customerPhone.isNotEmpty) customerPhone,
                                    _dateTimeValue(ticket['created_at']),
                                  ].where((value) => value.isNotEmpty).join(' · ')),
                                  dense: true,
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(_stringValue(ticket['message'])),
                                ),
                                if (messages is List)
                                  ...messages.whereType<Map<String, dynamic>>().map(
                                        (message) {
                                          final sender = message['users'];
                                          final senderRole = sender
                                                  is Map<String, dynamic>
                                              ? _stringValue(sender['role'])
                                                  .toLowerCase()
                                              : '';
                                          final senderName =
                                              sender is Map<String, dynamic>
                                                  ? [
                                                      _stringValue(
                                                          sender['first_name']),
                                                      _stringValue(
                                                          sender['last_name']),
                                                    ]
                                                      .where((part) =>
                                                          part.isNotEmpty)
                                                      .join(' ')
                                                  : '';
                                          final senderLabel =
                                              senderRole.contains('admin')
                                                  ? 'Admin${senderName.isEmpty ? '' : ' · $senderName'}'
                                                  : 'User${senderName.isEmpty ? '' : ' · $senderName'}';
                                          final sentAt = _dateTimeValue(
                                              message['created_at']);
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(_stringValue(
                                              message['message'],
                                            )),
                                            subtitle: Text([
                                              senderLabel,
                                              sentAt,
                                            ]
                                                .where((part) => part.isNotEmpty)
                                                .join(' · ')),
                                          );
                                        },
                                      ),
                                const Divider(height: 24),
                                TextField(
                                  controller: _controllerFor(id),
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: 5000,
                                  decoration: const InputDecoration(
                                    labelText: 'Reply to the user',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: id.isEmpty ||
                                            _sendingTicketId == id
                                        ? null
                                        : () => _sendReply(id),
                                    icon: _sendingTicketId == id
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.send),
                                    label: const Text('Send reply'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
