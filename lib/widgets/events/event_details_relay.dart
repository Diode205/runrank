import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/widgets/events/event_details_base.dart';
import 'package:runrank/widgets/events/event_details_dialogs.dart';
import 'package:runrank/widgets/events/event_venue_preview.dart';

/// Event details page for relay events (Relay)
/// Group 3: Relay with multi-stage selection, pacing, and support roles
class RelayEventDetailsPage extends StatefulWidget {
  final ClubEvent event;

  const RelayEventDetailsPage({super.key, required this.event});

  @override
  State<RelayEventDetailsPage> createState() => _RelayEventDetailsPageState();
}

class _RelayEventDetailsPageState extends State<RelayEventDetailsPage>
    with EventDetailsBaseMixin<RelayEventDetailsPage> {
  // Relay-specific stages
  final List<Map<String, dynamic>> relayStages = [
    {'stage': 1, 'distance': '16.32 miles', 'details': 'Start to Kings Lynn'},
    {
      'stage': 2,
      'distance': '13.75 miles',
      'details': 'Hunstanton to Burnham Overy Staithe',
    },
    {
      'stage': 3,
      'distance': '5.76 miles',
      'details': 'Burnham Overy Staithe to Wells-next-the-Sea',
    },
    {
      'stage': 4,
      'distance': '11.14 miles',
      'details': 'Wells-next-the-Sea to Cley',
    },
    {'stage': 5, 'distance': '10.81 miles', 'details': 'Cley to Cromer'},
    {'stage': 6, 'distance': '7.9 miles', 'details': 'Cromer to Mundesley'},
    {
      'stage': 7,
      'distance': '9.24 miles',
      'details': 'Mundesley to Lessingham',
    },
    {'stage': 8, 'distance': '7.52 miles', 'details': 'Lessingham to Horsey'},
    {'stage': 9, 'distance': '16.6 miles', 'details': 'Horsey to Belton'},
    {'stage': 10, 'distance': '16.5 miles', 'details': 'Belton to Ditchingham'},
    {'stage': 11, 'distance': '14.9 miles', 'details': 'Ditchingham to Scole'},
    {'stage': 12, 'distance': '18.88 miles', 'details': 'Scole to Thetford'},
    {'stage': 13, 'distance': '15.0 miles', 'details': 'Thetford to Feltwell'},
    {
      'stage': 14,
      'distance': '7.27 miles',
      'details': 'Feltwell to Wissington',
    },
    {
      'stage': 15,
      'distance': '10.59 miles',
      'details': 'Wissington to Downham Market',
    },
    {
      'stage': 16,
      'distance': '5.49 miles',
      'details': 'Downham Market to Stowbridge',
    },
    {'stage': 17, 'distance': '11.73 miles', 'details': 'Stowbridge to Finish'},
  ];

  // Ekiden relay legs (6-leg format)
  final List<Map<String, dynamic>> ekidenLegs = const [
    {'stage': 1, 'distance': '7.2K', 'details': 'Leg 1 – 3 laps'},
    {'stage': 2, 'distance': '5K', 'details': 'Leg 2 – 2 laps'},
    {'stage': 3, 'distance': '10K', 'details': 'Leg 3 – 4 laps'},
    {'stage': 4, 'distance': '5K', 'details': 'Leg 4 – 2 laps'},
    {'stage': 5, 'distance': '10K', 'details': 'Leg 5 – 4 laps'},
    {'stage': 6, 'distance': '5K', 'details': 'Leg 6 – 2 laps'},
  ];

  @override
  ClubEvent get event => widget.event;

  bool get _isEkidenRelay {
    final t = widget.event.relayTeam?.trim().toLowerCase() ?? '';
    return t.startsWith('ekiden');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xBB1a1a1a),
        elevation: 1,
        title: Text(
          e.title ?? "Event Details",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xBBFFD300).withValues(alpha: 0.7),
                const Color(0xBB0057B7).withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
              children: [
                // Cancelled event banner
                ...(e.isCancelled
                    ? [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0x4DFF0000),
                                const Color(0x1AFF0000),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x80FF0000),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "CANCELLED — ${e.cancelReason ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]
                    : []),

                // Event header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade800.withValues(alpha: 0.5),
                        Colors.grey.shade900.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFD300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFFFFD300),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${weekday(dt)}, ${dt.day} ${month(dt.month)} ${dt.year}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x330057B7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.access_time,
                              color: Color(0xFF0057B7),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white12),

                      // Relay type chip (RNR vs Ekiden)
                      if (e.relayTeam != null && e.relayTeam!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isEkidenRelay
                                  ? const Color(0x3322C55E)
                                  : const Color(0x334A90E2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isEkidenRelay
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFF4A90E2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isEkidenRelay ? Icons.groups_2 : Icons.route,
                                  size: 16,
                                  color: _isEkidenRelay
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFF4A90E2),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isEkidenRelay ? 'Ekiden Relay' : 'RNR Relay',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Hosted By
                      Text(
                        "Hosted By",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.hostOrDirector.isNotEmpty
                            ? e.hostOrDirector
                            : "Not specified",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Divider(height: 32, color: Colors.white12),

                      // Details
                      Text(
                        "Details",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.description.isEmpty
                            ? "No extra details yet. Check the map & weather above or contact the host if you have questions."
                            : e.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.latitude != null && e.longitude != null) ...[
                  const SizedBox(height: 20),
                  EventVenuePreview(event: e, onOpenMaps: openMaps),
                ],
                const SizedBox(height: 24),

                // Responses section
                Text(
                  "Responses",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD300),
                  ),
                ),
                const SizedBox(height: 8),
                _buildParticipationSection(),
                const SizedBox(height: 20),

                // Participant counts with support role breakdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Builder(
                    builder: (_) {
                      final items = _getParticipantLines();
                      final children = <Widget>[];
                      for (var i = 0; i < items.length; i++) {
                        children.add(items[i]);
                        if (i < items.length - 1) {
                          children.add(
                            const Divider(height: 1, color: Colors.white12),
                          );
                        }
                      }
                      return Column(children: children);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Message host button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0057B7), Color(0xFF003F8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x4D0057B7),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _contactHost(),
                    icon: const Icon(Icons.message),
                    label: const Text("Message Host/Coach"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Comments section
                Text("Comments", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                buildInlineCommentsPreview(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x40000000),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x40000000),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white12,
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          minLines: 1,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            isCollapsed: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) async {
                            await _submitComment();
                            commentController.clear();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white70),
                        onPressed: () async {
                          if (commentController.text.trim().isEmpty) return;
                          await _submitComment();
                          commentController.clear();
                        },
                      ),
                    ],
                  ),
                ),

                // Admin controls moved to swipe on calendar
                // Edit (left-to-right) and Cancel (right-to-left)
              ],
            ),
    );
  }

  Widget _buildParticipationSection() {
    final hasResponse = myResponse != null;
    if (widget.event.isCancelled) return const SizedBox.shrink();

    if (hasResponse) {
      final responseType = myResponse!["response_type"] as String?;
      return Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your participation:",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              // Running section
              if (responseType == "running" || myRelayStages.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Running",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (myRelayStages.isNotEmpty)
                          Text(
                            _isEkidenRelay
                                ? "Legs ${myRelayStages.join(", ")}"
                                : "Stage ${myRelayStages.join(", ")}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        if (myPredictedPace != null)
                          Text(
                            "Pace ${secondsToMMSS(myPredictedPace!)}/mile",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _deleteRole('type'),
                      child: const Text('❌', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Support roles (RNR relay only)
              if (!_isEkidenRelay && myRelayRoles.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Support",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          myRelayRoles.join(", "),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _deleteRole('roles'),
                      child: const Text('❌', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Marshalling (RNR relay only)
              if (!_isEkidenRelay && responseType == "marshalling") ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "🦺 Stage 6 Marshal",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deleteRole('type'),
                      child: const Text('❌', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ],
              if (!_isEkidenRelay) ...[
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: _addRoleClicked,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Role"),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // New response options
    if (_isEkidenRelay) {
      // Ekiden: only allow Running responses
      return Center(
        child: FilledButton.icon(
          onPressed: () => showRelayRunningDialog(),
          icon: const Icon(Icons.directions_run),
          label: const Text("Running"),
        ),
      );
    }

    // RNR relay: full set of response buttons
    final marshalDate = widget.event.marshalCallDate;
    final canMarshal =
        marshalDate == null || DateTime.now().isAfter(marshalDate);

    return Column(
      children: [
        if (marshalDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Marshal Call Date On: ${weekday(marshalDate)}, ${marshalDate.day} ${month(marshalDate.month)} ${marshalDate.year}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Run button - opens stage selector
            FilledButton(
              onPressed: () => showRelayRunningDialog(),
              child: const Text("🏃🏽", style: TextStyle(fontSize: 24)),
            ),
            // Marshal button
            FilledButton(
              onPressed: canMarshal
                  ? () => submitResponse(type: "volunteer")
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "You will be notified when Marshall call is opened",
                        ),
                      ),
                    ),
              child: const Text("🦺", style: TextStyle(fontSize: 24)),
            ),
            // Support button - opens role selector
            FilledButton(
              onPressed: () => showRelaySupportingDialog(),
              child: const Text("⚙️", style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantLine(
    String label,
    int count,
    List<Map<String, dynamic>> participants, {
    VoidCallback? onTap,
    Map<String, int>? supportRoleCounts,
  }) {
    return InkWell(
      onTap: count > 0 ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (supportRoleCounts != null) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _supportCounterChip(
                    "timekeeping",
                    "🧭",
                    supportRoleCounts['timekeeping'] ?? 0,
                  ),
                  _supportCounterChip(
                    "cycling",
                    "🚴",
                    supportRoleCounts['cycling'] ?? 0,
                  ),
                  _supportCounterChip(
                    "driving",
                    "🚐",
                    supportRoleCounts['driving'] ?? 0,
                  ),
                  _supportCounterChip(
                    "team_lead",
                    "📋",
                    supportRoleCounts['team_lead'] ?? 0,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _supportCounterChip(String role, String icon, int count) {
    return InkWell(
      onTap: count > 0 ? () => _showSupportersByRole(role) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 17, 14, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getParticipantLines() {
    // For Ekiden, only show running participants; RNR keeps full breakdown
    if (_isEkidenRelay) {
      return [
        _buildParticipantLine(
          "🏃‍♀️ Running",
          runners.length,
          runners,
          onTap: () => _showRelayRunningList(),
        ),
      ];
    }

    final roleCounts = supportRoleBreakdown();

    return [
      _buildParticipantLine(
        "🏃‍♀️ Running",
        runners.length,
        runners,
        onTap: () => _showRelayRunningList(),
      ),
      _buildParticipantLine(
        "🦺 Stage 6 Marshals",
        volunteers.length,
        volunteers,
        onTap: () => _showMarshalList(),
      ),
      _buildParticipantLine(
        "⚙️ Support Crew",
        supporters.length,
        supporters,
        onTap: () => _showSupportList(),
        supportRoleCounts: roleCounts,
      ),
    ];
  }

  Future<void> _deleteRole(String roleType, [String? specificRole]) async {
    switch (roleType) {
      case 'type':
        // Clear entire response
        await cancelMyPlan();
        if (mounted) {
          setState(() {
            myResponse = null;
            myRelayStages = [];
            myRelayRoles = [];
            myPredictedPace = null;
            myPredictedFinishHHMMSS = null;
          });
        }
        return;
      case 'roles':
        // Clear all support roles
        myRelayRoles = [];
        break;
      case 'stages':
        myRelayStages = [];
        break;
      case 'pace':
        myPredictedPace = null;
        myPredictedFinishHHMMSS = null;
        break;
      case 'role':
        if (specificRole != null) {
          myRelayRoles.remove(specificRole);
          // If no more roles, clear the entire response
          if (myRelayRoles.isEmpty && myRelayStages.isEmpty) {
            await cancelMyPlan();
            if (mounted) {
              setState(() {
                myResponse = null;
                myPredictedPace = null;
                myPredictedFinishHHMMSS = null;
              });
            }
            return;
          }
        }
        break;
    }

    // Update response after deletion
    if (mounted) {
      submitResponse(
        type: myResponse?["response_type"] ?? "unavailable",
        relayStages: myRelayStages.isNotEmpty ? myRelayStages : null,
        relayRoles: myRelayRoles.isNotEmpty ? myRelayRoles : null,
        predictedPace: myPredictedPace,
      );
    }
  }

  Future<void> _addRoleClicked() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Add Role"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'running'),
            child: const Row(
              children: [
                Icon(Icons.directions_run),
                SizedBox(width: 8),
                Text('Running'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'marshal'),
            child: const Row(
              children: [
                Icon(Icons.safety_check),
                SizedBox(width: 8),
                Text('Marshal (Stage 6)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'support'),
            child: const Row(
              children: [
                Icon(Icons.group_add),
                SizedBox(width: 8),
                Text('Support'),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == 'running') {
      await showRelayRunningDialog();
    } else if (choice == 'marshal') {
      await submitResponse(type: "volunteer");
    } else if (choice == 'support') {
      await showRelaySupportingDialog();
    }
  }

  Future<void> showRelayRunningDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RelayRunningDialog(
        relayStages: _isEkidenRelay ? ekidenLegs : relayStages,
        initialSelectedStages: List<int>.from(myRelayStages),
        initialPace: myPredictedPace != null
            ? secondsToMMSS(myPredictedPace!)
            : null,
      ),
    );
    if (result != null) {
      myRelayStages = result['stages'];
      final paceString = (result['pace'] as String?)?.trim();
      final paceSeconds = mmssToSeconds(paceString);

      if (paceString != null && paceString.isNotEmpty && paceSeconds == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Enter pace between 02:00 and 20:00 (e.g., 07:30).'),
          ),
        );
        return;
      }

      if (paceString == null || paceString.isEmpty) {
        // Leave pace unchanged unless the user explicitly clears via the delete action.
      } else {
        myPredictedPace = paceSeconds;
      }

      submitResponse(
        type: "run",
        relayStages: myRelayStages,
        relayRoles: myRelayRoles.isNotEmpty ? myRelayRoles : null,
        predictedPace: myPredictedPace,
      );
    }
  }

  Future<void> showRelaySupportingDialog() async {
    final roles = await showDialog<List<String>>(
      context: context,
      builder: (_) => RelaySupportingDialog(
        initialSelectedRoles: List<String>.from(myRelayRoles),
      ),
    );
    if (roles != null && roles.isNotEmpty) {
      myRelayRoles = roles;
      submitResponse(
        type: "support",
        relayRoles: myRelayRoles,
        relayStages: myRelayStages.isNotEmpty ? myRelayStages : null,
        predictedPace: myPredictedPace,
      );
    }
  }

  Future<void> _showSupportersByRole(String role) async {
    // Filter from in-memory responses to include anyone who selected this role.
    final filtered = <Map<String, dynamic>>[];
    for (final e in supporters) {
      final raw = e["relay_roles_json"];
      try {
        final roles = raw is String ? jsonDecode(raw) : raw;
        if (roles is List && roles.contains(role)) {
          filtered.add(e);
        }
      } catch (_) {
        // ignore malformed
      }
    }

    // Fetch names for these user_ids
    final ids = filtered
        .map((e) => e["user_id"] as String?)
        .whereType<String>()
        .toSet();
    final names = await fetchNamesForIds(ids);

    final attendees = filtered
        .map((e) => {"fullName": names[e["user_id"]] ?? "Member"})
        .toList();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Support: $role"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: attendees.isEmpty
              ? const Center(
                  child: Text(
                    "No supporters yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    final a = attendees[i];
                    final name = a['fullName'] ?? 'Member';
                    return ListTile(title: Text(name));
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openRelayDebugView() async {
    try {
      final rows = await supabase
          .from("club_event_responses")
          .select()
          .eq("event_id", widget.event.id);

      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final ids = list
          .map((e) => e["user_id"] as String?)
          .whereType<String>()
          .toSet();
      final names = await fetchNamesForIds(ids);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Relay Responses Debug',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Raw club_event_responses for this relay, including relay_stages_json, relay_stage, roles, and predicted pace.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              'No responses yet',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white24),
                            itemBuilder: (_, i) {
                              final row = list[i];
                              final userId = row['user_id'] as String?;
                              final name = userId != null
                                  ? (names[userId] ?? 'Member')
                                  : 'Unknown';
                              final responseType =
                                  row['response_type']?.toString() ?? '';
                              final relayStage = row['relay_stage'];
                              final relayStagesJson = row['relay_stages_json'];
                              final relayRolesJson = row['relay_roles_json'];
                              final pace = row['predicted_pace'];
                              final expected = row['expected_time_seconds'];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'type=$responseType  stage=$relayStage  stages_json=${relayStagesJson ?? 'null'}\nroles_json=${relayRolesJson ?? 'null'}  pace=${pace ?? 'null'}  expected=${expected ?? 'null'}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      height: 1.3,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading debug data: $e')));
    }
  }

  Future<void> _showRelayRunningList() async {
    // Build in-memory view of runners with names, stages, and pace.
    final ids = runners
        .map((e) => e["user_id"] as String?)
        .whereType<String>()
        .toSet();
    final names = await fetchNamesForIds(ids);

    final items = <Map<String, dynamic>>[];
    for (final r in runners) {
      final userId = r["user_id"] as String?;
      if (userId == null) continue;

      final name = names[userId] ?? "Member";

      // Prefer new relay_stages_json, but still handle
      // legacy relay_stage values if present.
      final stages = <int>[];
      final stagesJson = r["relay_stages_json"];
      if (stagesJson != null) {
        try {
          final raw = stagesJson is String
              ? jsonDecode(stagesJson)
              : stagesJson;
          if (raw is List) {
            for (final v in raw) {
              if (v is num) stages.add(v.toInt());
            }
          }
        } catch (_) {}
      }
      if (stages.isEmpty) {
        final stageValue = r["relay_stage"];
        if (stageValue is int) {
          stages.add(stageValue);
        }
      }

      final paceSeconds = r["predicted_pace"] as int?;
      items.add({"name": name, "stages": stages, "paceSeconds": paceSeconds});
    }

    String buildExportText() {
      final buffer = StringBuffer();
      buffer.writeln(
        "Relay Running List — ${event.title ?? "Relay"} (${weekday(event.dateTime)}, ${event.dateTime.day} ${month(event.dateTime.month)} ${event.dateTime.year})",
      );
      buffer.writeln();

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final name = item["name"] as String? ?? "Member";
        final stages = (item["stages"] as List<int>?) ?? const [];
        final paceSeconds = item["paceSeconds"] as int?;

        final parts = <String>[];
        if (stages.isNotEmpty) {
          if (_isEkidenRelay) {
            if (stages.length == 1) {
              parts.add("Leg ${stages.first}");
            } else {
              parts.add("Legs ${stages.join(", ")}");
            }
          } else {
            if (stages.length == 1) {
              parts.add("Stage ${stages.first}");
            } else {
              parts.add("Stages ${stages.join(", ")}");
            }
          }
        }
        if (paceSeconds != null) {
          parts.add("Pace ${secondsToMMSS(paceSeconds)}/mile");
        }

        final detail = parts.isEmpty ? "" : " — ${parts.join(" • ")}";
        buffer.writeln("${i + 1}. $name$detail");
      }

      return buffer.toString();
    }

    if (!mounted) return;
    final exportText = buildExportText();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🏃‍♀️ Running List"),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    "No runners yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final name = item["name"] as String? ?? "Member";
                    final stages = (item["stages"] as List<int>?) ?? const [];
                    final paceSeconds = item["paceSeconds"] as int?;

                    final parts = <String>[];
                    if (stages.isNotEmpty) {
                      if (_isEkidenRelay) {
                        if (stages.length == 1) {
                          parts.add("Leg ${stages.first}");
                        } else {
                          parts.add("Legs ${stages.join(", ")}");
                        }
                      } else {
                        if (stages.length == 1) {
                          parts.add("Stage ${stages.first}");
                        } else {
                          parts.add("Stages ${stages.join(", ")}");
                        }
                      }
                    }
                    if (paceSeconds != null) {
                      parts.add("Pace ${secondsToMMSS(paceSeconds)}/mile");
                    }

                    final subtitle = parts.isEmpty ? null : parts.join(" • ");

                    return ListTile(
                      title: Text(name),
                      subtitle: subtitle != null
                          ? Text(subtitle)
                          : const SizedBox.shrink(),
                    );
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _exportListAsPdf("Relay Running List", exportText);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Export PDF"),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: exportText));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Running list copied")),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy"),
          ),
          TextButton.icon(
            onPressed: () async {
              await _publishListAsPost(
                title: "Relay Running List — ${event.title ?? "Relay"}",
                content: exportText,
              );
            },
            icon: const Icon(Icons.send),
            label: const Text("Publish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _showMarshalList() async {
    final ids = volunteers
        .map((e) => e["user_id"] as String?)
        .whereType<String>()
        .toSet();
    final names = await fetchNamesForIds(ids);

    final attendees = volunteers
        .map((e) => names[e["user_id"]] ?? "Member")
        .toList();

    String buildExportText() {
      final buffer = StringBuffer();
      buffer.writeln(
        "Stage 6 Marshal List — ${event.title ?? "Relay"} (${weekday(event.dateTime)}, ${event.dateTime.day} ${month(event.dateTime.month)} ${event.dateTime.year})",
      );
      buffer.writeln();
      for (var i = 0; i < attendees.length; i++) {
        buffer.writeln("${i + 1}. ${attendees[i]}");
      }
      return buffer.toString();
    }

    if (!mounted) return;
    final exportText = buildExportText();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🦺 Stage 6 Marshals"),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: attendees.isEmpty
              ? const Center(
                  child: Text(
                    "No marshals yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    return ListTile(title: Text(attendees[i]));
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _exportListAsPdf("Stage 6 Marshal List", exportText);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Export PDF"),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: exportText));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Marshal list copied")),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy"),
          ),
          TextButton.icon(
            onPressed: () async {
              await _publishListAsPost(
                title: "Stage 6 Marshal List — ${event.title ?? "Relay"}",
                content: exportText,
              );
            },
            icon: const Icon(Icons.send),
            label: const Text("Publish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportList() async {
    final ids = supporters
        .map((e) => e["user_id"] as String?)
        .whereType<String>()
        .toSet();
    final names = await fetchNamesForIds(ids);

    final items = <Map<String, dynamic>>[];
    for (final s in supporters) {
      final userId = s["user_id"] as String?;
      if (userId == null) continue;

      final name = names[userId] ?? "Member";
      final raw = s["relay_roles_json"];
      final roles = <String>[];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            for (final r in decoded) {
              if (r is String) roles.add(r);
            }
          }
        } catch (_) {}
      } else if (raw is List) {
        for (final r in raw) {
          if (r is String) roles.add(r);
        }
      }

      items.add({"name": name, "roles": roles});
    }

    String buildExportText() {
      final buffer = StringBuffer();
      buffer.writeln(
        "Support Crew — ${event.title ?? "Relay"} (${weekday(event.dateTime)}, ${event.dateTime.day} ${month(event.dateTime.month)} ${event.dateTime.year})",
      );
      buffer.writeln();

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final name = item["name"] as String? ?? "Member";
        final roles = (item["roles"] as List<String>?) ?? const [];
        final roleText = roles.isEmpty ? "" : " — Roles: ${roles.join(", ")}";
        buffer.writeln("${i + 1}. $name$roleText");
      }

      return buffer.toString();
    }

    if (!mounted) return;
    final exportText = buildExportText();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚙️ Support Crew"),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    "No supporters yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final name = item["name"] as String? ?? "Member";
                    final roles = (item["roles"] as List<String>?) ?? const [];
                    final subtitle = roles.isEmpty
                        ? null
                        : "Roles: ${roles.join(", ")}";
                    return ListTile(
                      title: Text(name),
                      subtitle: subtitle != null
                          ? Text(subtitle)
                          : const SizedBox.shrink(),
                    );
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _exportListAsPdf("Support Crew", exportText);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Export PDF"),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: exportText));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Support list copied")),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copy"),
          ),
          TextButton.icon(
            onPressed: () async {
              await _publishListAsPost(
                title: "Support Crew — ${event.title ?? "Relay"}",
                content: exportText,
              );
            },
            icon: const Icon(Icons.send),
            label: const Text("Publish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportListAsPdf(String title, String content) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(content, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      );

      final safeTitle = title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${safeTitle}_${event.id}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _publishListAsPost({
    required String title,
    required String content,
  }) async {
    if (await UserService.isBlocked(context: context)) {
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post.')),
        );
      }
      return;
    }

    try {
      // Resolve author display name similar to CreatePostPage.
      String authorName = 'Unknown';
      try {
        final profile = await supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          authorName = name.trim();
        } else {
          final displayName = user.userMetadata?['full_name'] as String?;
          if (displayName != null && displayName.trim().isNotEmpty) {
            authorName = displayName.trim();
          }
        }
      } catch (_) {
        final displayName = user.userMetadata?['full_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          authorName = displayName.trim();
        }
      }

      final isAdmin = await UserService.isAdmin();
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 365));

      await supabase.from('club_posts').insert({
        'title': title,
        'content': content,
        'author_id': user.id,
        'author_name': authorName,
        'expiry_date': expiry.toIso8601String(),
        'created_at': now.toIso8601String(),
        'is_approved': isAdmin,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmin
                  ? 'Post published with latest relay lists.'
                  : 'Post created — awaiting admin approval.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error publishing post: $e')));
      }
    }
  }

  Future<void> _contactHost() async {
    final hostUserId =
        widget.event.hostUserId ??
        widget.event.createdBy ??
        supabase.auth.currentUser?.id;
    if (hostUserId == null || hostUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No creator id found for this event. Please re-save the event.",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HostChatSheet(
        event: widget.event,
        hostUserId: hostUserId,
        hostDisplayName: widget.event.hostOrDirector.isNotEmpty
            ? widget.event.hostOrDirector
            : "Host / Coach",
        messageController: messageController,
        loadMessages: getHostMessagesWithNames,
        sendMessage: sendHostMessage,
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = commentController.text.trim();
    if (comment.isEmpty) return;

    await addComment(comment);
  }

  @override
  Future<Map<String, String>> fetchNamesForIds(Set<String> userIds) async {
    return super.fetchNamesForIds(userIds);
  }
}
