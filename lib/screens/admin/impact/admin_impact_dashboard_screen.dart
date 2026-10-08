import 'package:flutter/material.dart';

import '../../../models/bloom_reward.dart';
import '../../../models/bloom_session.dart';
import '../../../services/partner_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/page_scaffold.dart';
import '../../../widgets/common/section_header.dart';
import 'impact_export.dart';

/// Admin-only cross-session impact report. Every metric here is computed
/// live from Firestore — session_registrations, session_surveys,
/// session_checkins, session_badges, reward_redemptions — never hard-coded.
/// Confidence CHANGE is reported only over the subset of participants who
/// have BOTH a pre-session check-in and a post-session survey for the
/// same session; everything else is either a direct count or an
/// explicitly-labeled self-reported percentage.
class AdminImpactDashboardScreen extends StatefulWidget {
  const AdminImpactDashboardScreen({super.key});

  @override
  State<AdminImpactDashboardScreen> createState() => _AdminImpactDashboardScreenState();
}

class _AdminImpactDashboardScreenState extends State<AdminImpactDashboardScreen> {
  String? _programFilter;
  String? _ageGroupFilter;
  DateTimeRange? _dateFilter;
  bool _loading = false;
  List<BloomSession> _matchingSessions = [];
  Map<String, SessionImpactBundle> _bundles = {};
  List<RewardRedemption> _allRedemptions = [];
  List<BloomReward> _allRewards = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final allSessions = await SessionService.instance.watchAllSessions().first;
      final filtered = allSessions.where((s) {
        if (_programFilter != null && s.program != _programFilter) return false;
        if (_ageGroupFilter != null && s.ageGroup != _ageGroupFilter) return false;
        if (_dateFilter != null && (s.date.isBefore(_dateFilter!.start) || s.date.isAfter(_dateFilter!.end.add(const Duration(days: 1))))) return false;
        return true;
      }).toList();

      final bundles = <String, SessionImpactBundle>{};
      for (final session in filtered) {
        bundles[session.id] = await SessionService.instance.fetchSessionImpactBundle(session);
      }

      final redemptions = await PartnerService.instance.watchAllRedemptions().first;
      final rewards = await PartnerService.instance.watchAllRewards().first;

      if (mounted) {
        setState(() {
          _matchingSessions = filtered;
          _bundles = bundles;
          _allRedemptions = redemptions;
          _allRewards = rewards;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRegistered = _bundles.values.fold(0, (sum, b) => sum + b.registeredCount);
    final totalAttended = _bundles.values.fold(0, (sum, b) => sum + b.attendedCount);
    final totalCompleted = _bundles.values.fold(0, (sum, b) => sum + b.completedCount);
    final attendanceRate = totalRegistered == 0 ? 0.0 : (totalAttended / totalRegistered) * 100;

    final comparablePairs = _bundles.values.fold(0, (sum, b) => sum + b.comparableConfidencePairCount);
    final weightedChangeSum = _bundles.values.fold(0.0, (sum, b) => sum + (b.avgConfidenceChange ?? 0) * b.comparableConfidencePairCount);
    final avgConfidenceChange = comparablePairs == 0 ? null : weightedChangeSum / comparablePairs;

    final surveyCount = _bundles.values.fold(0, (sum, b) => sum + b.surveyResponseCount);
    final weightedLearningSum = _bundles.values.fold(0.0, (sum, b) => sum + (b.reportedLearningPercent ?? 0) * b.surveyResponseCount);
    final weightedApplicationSum = _bundles.values.fold(0.0, (sum, b) => sum + (b.reportedApplicationPercent ?? 0) * b.surveyResponseCount);
    final avgReportedLearning = surveyCount == 0 ? null : weightedLearningSum / surveyCount;
    final avgReportedApplication = surveyCount == 0 ? null : weightedApplicationSum / surveyCount;

    final sessionIds = _matchingSessions.map((s) => s.id).toSet();
    final relevantRedemptions = sessionIds.isEmpty && _programFilter == null && _ageGroupFilter == null && _dateFilter == null
        ? _allRedemptions
        : _allRedemptions; // redemptions aren't session-scoped; shown as an overall program total
    final rewardsRedeemedCount = relevantRedemptions.where((r) => r.status == RedemptionStatus.used).length;
    final totalPartnerValue = _allRewards.fold(0.0, (sum, r) {
      final usedForThisReward = relevantRedemptions.where((red) => red.rewardId == r.id && red.status == RedemptionStatus.used).length;
      return sum + (r.value * usedForThisReward);
    });
    final badgesEarnedCount = _bundles.values.fold(0, (sum, b) => sum + b.completedCount);

    return PageScaffold(
      title: 'Impact Dashboard',
      children: [
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('Program', _programFilter, () => _pickProgram()),
                  _filterChip('Age Group', _ageGroupFilter, () => _pickAgeGroup()),
                  _filterChip('Date Range', _dateFilter == null ? null : '${_fmt(_dateFilter!.start)} – ${_fmt(_dateFilter!.end)}', () => _pickDateRange()),
                  if (_programFilter != null || _ageGroupFilter != null || _dateFilter != null)
                    ActionChip(
                      label: const Text('Clear', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _programFilter = null;
                          _ageGroupFilter = null;
                          _dateFilter = null;
                        });
                        _load();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator(color: AppColors.royal)))
        else ...[
          const SectionHeader('Sessions & Attendance'),
          BloomCard(
            child: Column(
              children: [
                _metricRow('Sessions in scope', '${_matchingSessions.length}'),
                const Divider(height: 20),
                _metricRow('Registered', '$totalRegistered'),
                const Divider(height: 20),
                _metricRow('Attended', '$totalAttended'),
                const Divider(height: 20),
                _metricRow('Attendance Rate', '${attendanceRate.toStringAsFixed(1)}%'),
                const Divider(height: 20),
                _metricRow('Completed (survey + attended)', '$totalCompleted'),
              ],
            ),
          ),
          const SectionHeader('Self-Reported Outcomes'),
          BloomCard(
            child: Column(
              children: [
                _metricRow('Survey responses', '$surveyCount'),
                const Divider(height: 20),
                _metricRow('Reported learning (rated 4-5/5)', avgReportedLearning == null ? 'Not enough data' : '${avgReportedLearning.toStringAsFixed(1)}%'),
                const Divider(height: 20),
                _metricRow('Reported application ("Yes")', avgReportedApplication == null ? 'Not enough data' : '${avgReportedApplication.toStringAsFixed(1)}%'),
              ],
            ),
          ),
          const SectionHeader('Confidence Change (measured)'),
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Computed only for participants with BOTH a pre-session check-in and a post-session survey for the same session — never a population-wide estimate.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.4),
                ),
                const SizedBox(height: 10),
                _metricRow('Comparable participant pairs', '$comparablePairs'),
                const Divider(height: 20),
                _metricRow('Avg. confidence change', avgConfidenceChange == null ? 'Not enough data' : '${avgConfidenceChange >= 0 ? '+' : ''}${avgConfidenceChange.toStringAsFixed(2)} / 5'),
              ],
            ),
          ),
          const SectionHeader('Badges & Rewards'),
          BloomCard(
            child: Column(
              children: [
                _metricRow('Badges earned (in scope)', '$badgesEarnedCount'),
                const Divider(height: 20),
                _metricRow('Rewards redeemed (program-wide)', '$rewardsRedeemedCount'),
                const Divider(height: 20),
                _metricRow('Total Community Partner reward value', '\$${totalPartnerValue.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SectionHeader('Export'),
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exports respect the filters above and contain aggregated, de-identified session-level data only.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _matchingSessions.isEmpty ? null : () => exportImpactReportCsv(context, sessions: _matchingSessions, bundles: _bundles),
                        icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.royal),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 12)),
                        label: const Text('CSV', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _matchingSessions.isEmpty ? null : () => exportImpactReportExcel(context, sessions: _matchingSessions, bundles: _bundles),
                        icon: const Icon(Icons.grid_on_outlined, size: 16, color: AppColors.sage),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.sage), padding: const EdgeInsets.symmetric(vertical: 12)),
                        label: const Text('Excel', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _matchingSessions.isEmpty
                            ? null
                            : () => exportImpactReportPdf(context, sessions: _matchingSessions, bundles: _bundles, programFilter: _programFilter, ageGroupFilter: _ageGroupFilter),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.adminGoldDeep),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.adminGoldDeep), padding: const EdgeInsets.symmetric(vertical: 12)),
                        label: const Text('PDF', style: TextStyle(color: AppColors.adminGoldDeep, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

  Widget _filterChip(String label, String? value, VoidCallback onTap) {
    return ActionChip(
      label: Text(value == null ? label : '$label: $value', style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: value == null ? Colors.white : AppColors.royal.withValues(alpha: 0.1),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft))),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.royalDeep)),
      ],
    );
  }

  Future<void> _pickProgram() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: const Text('All Programs'), onTap: () => Navigator.of(sheetContext).pop()),
          ...kBloomSessionPrograms.map((p) => ListTile(title: Text(p), onTap: () => Navigator.of(sheetContext).pop(p))),
        ],
      ),
    );
    setState(() => _programFilter = selected);
    _load();
  }

  Future<void> _pickAgeGroup() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: const Text('All Age Groups'), onTap: () => Navigator.of(sheetContext).pop()),
          ...kBloomSessionAgeGroups.map((a) => ListTile(title: Text(a), onTap: () => Navigator.of(sheetContext).pop(a))),
        ],
      ),
    );
    setState(() => _ageGroupFilter = selected);
    _load();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 2));
    if (picked != null) {
      setState(() => _dateFilter = picked);
      _load();
    }
  }
}
