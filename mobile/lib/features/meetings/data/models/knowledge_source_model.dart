import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════
// Knowledge Source Kind
// ═══════════════════════════════════════════

enum KnowledgeSourceKind {
  documentation('Documentation'),
  requirements('Requirements'),
  meetingNotes('MeetingNotes'),
  unknown('Unknown');

  final String value;

  const KnowledgeSourceKind(this.value);

  static KnowledgeSourceKind fromJson(dynamic value) {
    return values.firstWhere(
      (item) => item.value.toLowerCase() == value.toString().toLowerCase(),
      orElse: () => unknown,
    );
  }
}

// ═══════════════════════════════════════════
// Meeting Mode
// ═══════════════════════════════════════════

enum KnowledgeMeetingMode {
  online('Online'),
  inPerson('InPerson');

  final String value;

  const KnowledgeMeetingMode(this.value);

  static KnowledgeMeetingMode? fromJson(dynamic value) {
    for (final item in values) {
      if (item.value.toLowerCase() == value.toString().toLowerCase()) {
        return item;
      }
    }

    return null;
  }
}

// ═══════════════════════════════════════════
// Processing Status
// ═══════════════════════════════════════════

enum KnowledgeSourceStatus {
  pendingExtraction('PendingExtraction'),
  extractionFailed('ExtractionFailed'),
  awaitingReview('AwaitingReview'),
  published('Published'),
  rejected('Rejected'),
  unknown('Unknown');

  final String value;

  const KnowledgeSourceStatus(this.value);

  static KnowledgeSourceStatus fromJson(dynamic value) {
    return values.firstWhere(
      (item) => item.value.toLowerCase() == value.toString().toLowerCase(),
      orElse: () => unknown,
    );
  }

  String get label {
    switch (this) {
      case pendingExtraction:
        return 'Processing';
      case extractionFailed:
        return 'Processing Failed';
      case awaitingReview:
        return 'Awaiting Review';
      case published:
        return 'Published';
      case rejected:
        return 'Rejected';
      case unknown:
        return 'Unknown';
    }
  }

  bool get isProcessing => this == pendingExtraction;

  bool get canRetry => this == extractionFailed;

  bool get isPublished => this == published;
}

// ═══════════════════════════════════════════
// Evidence Kind
// ═══════════════════════════════════════════

enum KnowledgeEvidenceKind {
  requirement('Requirement'),
  decision('Decision'),
  actionItem('ActionItem'),
  openQuestion('OpenQuestion'),
  blocker('Blocker'),
  unknown('Unknown');

  final String value;

  const KnowledgeEvidenceKind(this.value);

  static KnowledgeEvidenceKind fromJson(dynamic value) {
    return values.firstWhere(
      (item) => item.value.toLowerCase() == value.toString().toLowerCase(),
      orElse: () => unknown,
    );
  }

  String get label {
    switch (this) {
      case requirement:
        return 'Requirement';
      case decision:
        return 'Decision';
      case actionItem:
        return 'Action Item';
      case openQuestion:
        return 'Open Question';
      case blocker:
        return 'Blocker';
      case unknown:
        return 'Unknown';
    }
  }
}

// ═══════════════════════════════════════════
// Evidence Decision
// ═══════════════════════════════════════════

enum KnowledgeEvidenceDecision {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  unknown('Unknown');

  final String value;

  const KnowledgeEvidenceDecision(this.value);

  static KnowledgeEvidenceDecision fromJson(dynamic value) {
    return values.firstWhere(
      (item) => item.value.toLowerCase() == value.toString().toLowerCase(),
      orElse: () => unknown,
    );
  }
}

// ═══════════════════════════════════════════
// Knowledge Source Summary
// ═══════════════════════════════════════════

class KnowledgeSourceSummary extends Equatable {
  final String id;
  final String clientId;
  final String? projectId;
  final KnowledgeSourceKind kind;
  final String title;
  final int version;
  final int? publishedVersion;
  final KnowledgeSourceStatus status;

  const KnowledgeSourceSummary({
    required this.id,
    required this.clientId,
    this.projectId,
    required this.kind,
    required this.title,
    required this.version,
    this.publishedVersion,
    required this.status,
  });

  factory KnowledgeSourceSummary.fromJson(Map<String, dynamic> json) {
    return KnowledgeSourceSummary(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      projectId: json['projectId'] as String?,
      kind: KnowledgeSourceKind.fromJson(json['kind']),
      title: json['title'] as String,
      version: (json['version'] as num).toInt(),
      publishedVersion: (json['publishedVersion'] as num?)?.toInt(),
      status: KnowledgeSourceStatus.fromJson(json['status']),
    );
  }

  bool get isMeeting => kind == KnowledgeSourceKind.meetingNotes;

  bool get isProcessing => status.isProcessing;

  bool get canRetry => status.canRetry;

  bool get isPublished => status.isPublished;

  @override
  List<Object?> get props => [
    id,
    clientId,
    projectId,
    kind,
    title,
    version,
    publishedVersion,
    status,
  ];
}

// ═══════════════════════════════════════════
// Knowledge Evidence Model
// ═══════════════════════════════════════════

class KnowledgeEvidenceModel extends Equatable {
  final String id;
  final KnowledgeEvidenceKind kind;
  final String text;
  final String quote;
  final int quoteOffset;
  final KnowledgeEvidenceDecision decision;
  final bool? needsReview;

  // Retain the server's text. Older responses may only carry the prefix.
  bool get isProposal =>
      needsReview == true || text.trimLeft().startsWith('Proposed:');

  bool get isProposalPending =>
      isProposal &&
      (decision == KnowledgeEvidenceDecision.pending ||
          decision == KnowledgeEvidenceDecision.unknown);

  const KnowledgeEvidenceModel({
    required this.id,
    required this.kind,
    required this.text,
    required this.quote,
    required this.quoteOffset,
    required this.decision,
    this.needsReview,
  });

  factory KnowledgeEvidenceModel.fromJson(Map<String, dynamic> json) {
    return KnowledgeEvidenceModel(
      id: json['id'] as String,
      kind: KnowledgeEvidenceKind.fromJson(json['kind']),
      text: json['text'] as String,
      quote: json['quote'] as String,
      quoteOffset: (json['quoteOffset'] as num).toInt(),
      decision: KnowledgeEvidenceDecision.fromJson(json['decision']),
      needsReview: (json['needs_review'] is bool)
          ? json['needs_review'] as bool
          : (json['needsReview'] is bool)
          ? json['needsReview'] as bool
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    text,
    quote,
    quoteOffset,
    decision,
    needsReview,
  ];
}

// ═══════════════════════════════════════════
// Knowledge Source Details
// ═══════════════════════════════════════════

class KnowledgeSourceDetails extends Equatable {
  final KnowledgeSourceSummary source;
  final KnowledgeMeetingMode? meetingMode;
  final DateTime? meetingAt;
  final String? fileName;
  final String? sourceText;
  final List<KnowledgeEvidenceModel> evidence;
  final String? failureCode;

  const KnowledgeSourceDetails({
    required this.source,
    this.meetingMode,
    this.meetingAt,
    this.fileName,
    this.sourceText,
    this.evidence = const [],
    this.failureCode,
  });

  factory KnowledgeSourceDetails.fromJson(Map<String, dynamic> json) {
    return KnowledgeSourceDetails(
      source: KnowledgeSourceSummary.fromJson(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      meetingMode: KnowledgeMeetingMode.fromJson(json['meetingMode']),
      meetingAt: json['meetingAt'] == null
          ? null
          : DateTime.tryParse(json['meetingAt'] as String),
      fileName: json['fileName'] as String?,
      sourceText: json['sourceText'] as String?,
      evidence: (json['evidence'] as List? ?? [])
          .map(
            (item) => KnowledgeEvidenceModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      failureCode: json['failureCode'] as String?,
    );
  }

  String get id => source.id;

  String get title => source.title;

  KnowledgeSourceStatus get status => source.status;

  bool get isProcessing => source.isProcessing;

  bool get canRetry => source.canRetry;

  bool get hasSourceFile => fileName != null && fileName!.isNotEmpty;

  bool get hasEvidence => evidence.isNotEmpty;

  String? get extractionFailureMessage {
    if (status != KnowledgeSourceStatus.extractionFailed) {
      return null;
    }

    switch (failureCode) {
      case 'Unreadable':
        return 'The meeting content could not be read.';

      case 'ExtractionUnavailable':
        return 'AI extraction is temporarily unavailable. '
            'Please try again later.';

      case 'TimedOut':
        return 'AI processing took too long. '
            'Please retry the extraction.';

      default:
        return 'Unable to extract meeting results.';
    }
  }

  bool get isAwaitingReview => status == KnowledgeSourceStatus.awaitingReview;

  bool get isRejected => status == KnowledgeSourceStatus.rejected;

  bool get hasCompletedExtraction =>
      isAwaitingReview ||
      status == KnowledgeSourceStatus.published ||
      isRejected;

  bool get hasEmptyResults => hasCompletedExtraction && evidence.isEmpty;

  List<KnowledgeEvidenceModel> get uniqueEvidence {
    final items = <String, KnowledgeEvidenceModel>{};

    for (final item in evidence) {
      items.putIfAbsent(item.id, () => item);
    }

    return List.unmodifiable(items.values);
  }

  List<KnowledgeEvidenceModel> evidenceByKind(KnowledgeEvidenceKind kind) {
    return uniqueEvidence
        .where((item) => item.kind == kind)
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [
    source,
    meetingMode,
    meetingAt,
    fileName,
    sourceText,
    evidence,
    failureCode,
  ];
}

// ═══════════════════════════════════════════
// Create Knowledge Source Request
// ═══════════════════════════════════════════

class CreateKnowledgeSourceRequest {
  final String clientId;
  final String? projectId;
  final KnowledgeSourceKind kind;
  final String title;
  final String? text;
  final KnowledgeMeetingMode? meetingMode;
  final DateTime? meetingAt;

  const CreateKnowledgeSourceRequest({
    required this.clientId,
    this.projectId,
    this.kind = KnowledgeSourceKind.meetingNotes,
    required this.title,
    this.text,
    this.meetingMode,
    this.meetingAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'projectId': projectId,
      'kind': kind.value,
      'title': title.trim(),
      'text': text?.trim(),
      'meetingMode': meetingMode?.value,
      'meetingAt': meetingAt?.toUtc().toIso8601String(),
    };
  }
}
