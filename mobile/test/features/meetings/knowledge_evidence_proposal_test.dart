import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/meetings/data/models/knowledge_source_model.dart';

void main() {
  KnowledgeEvidenceModel evidence({
    String text = 'Example requirement',
    String decision = 'Pending',
    Map<String, dynamic> extra = const {},
  }) => KnowledgeEvidenceModel.fromJson({
    'id': 'test-item',
    'kind': 'Requirement',
    'text': text,
    'quote': '',
    'quoteOffset': 0,
    'decision': decision,
    ...extra,
  });

  test('snake_case needs_review flags a pending proposal', () {
    final item = evidence(extra: {'needs_review': true});
    expect(item.isProposalPending, isTrue);
  });

  test('camelCase flag and legacy prefix remain supported', () {
    expect(evidence(extra: {'needsReview': true}).isProposal, isTrue);
    final item = evidence(text: 'Proposed: Example requirement');
    expect(item.isProposalPending, isTrue);
    expect(item.text, 'Proposed: Example requirement');
  });

  test('normal pending evidence is not necessarily a proposal', () {
    expect(evidence().isProposal, isFalse);
  });

  test('a rejected or approved proposal is not pending review', () {
    for (final decision in ['Approved', 'Rejected']) {
      final item = evidence(text: 'Proposed: Example', decision: decision);
      expect(item.isProposal, isTrue);
      expect(item.isProposalPending, isFalse);
    }
  });

  test('a cleared server response no longer classifies as proposal', () {
    final item = evidence(decision: 'Approved', extra: {'needs_review': false});
    expect(item.isProposal, isFalse);
  });
}
