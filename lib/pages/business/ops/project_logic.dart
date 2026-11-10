/// A project can be sent for tokenization once the fields the form requires
/// are present. The server still accepts or rejects the request.
bool projectIsFilled(Map<dynamic, dynamic> project) {
  final name = '${project['project_name'] ?? ''}'.trim();
  final target = num.tryParse('${project['target_amount'] ?? ''}') ?? 0;
  final summary = '${project['summary'] ?? ''}'.trim();
  final description = '${project['description'] ?? ''}'.trim();
  return name.length >= 3 && target > 0 && (summary.isNotEmpty || description.isNotEmpty);
}

const submitForTokenizationLabel = 'Submit for tokenization';

/// Drafts and projects sent back for more information can be submitted.
bool projectCanSubmitForTokenization(String status) {
  return status.isEmpty ||
      status == 'draft' ||
      status == 'more_info_required';
}

/// What the business sees. `submitted` is not the same as `under review`.
String projectLifecycleLabel(String status) {
  switch (status) {
    case '':
    case 'draft':
      return 'Draft';
    case 'submitted':
      return 'Submitted';
    case 'under_review':
    case 'in_review':
      return 'Under review';
    case 'approved':
      return 'Approved';
    case 'listed':
      return 'Listed';
    case 'rejected':
      return 'Rejected';
    case 'more_info_required':
      return 'More info needed';
    default:
      return status.replaceAll('_', ' ');
  }
}
