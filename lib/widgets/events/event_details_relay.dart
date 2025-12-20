import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/events/event_details_base.dart';
import 'package:runrank/widgets/events/event_details_dialogs.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/services/notification_service.dart';

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
  bool _isAdmin = false;
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

  @override
  ClubEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Show admin controls if user is the creator OR has admin flag
    if (widget.event.createdBy != null && widget.event.createdBy == user.id) {
      setState(() => _isAdmin = true);
      return;
    }

    try {
      final isAdminProfile = await UserService.isAdmin();
      if (mounted) setState(() => _isAdmin = isAdminProfile);
    } catch (_) {
      // ignore lookup errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;
    final user = supabase.auth.currentUser;

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
                        Colors.grey.shade800.withValues(
                          alpha: Colors.grey.shade800.opacity * 0.5,
                        ),
                        Colors.grey.shade900.withValues(
                          alpha: Colors.grey.shade900.opacity * 0.5,
                        ),
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

                      // Venue
                      Text(
                        "Venue",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.venue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      ...(e.venueAddress.isNotEmpty
                          ? [
                              const SizedBox(height: 4),
                              Text(
                                e.venueAddress,
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ]
                          : []),
                      ...(e.latitude != null && e.longitude != null
                          ? [
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: openMaps,
                                icon: const Icon(Icons.map),
                                label: const Text("Open in Maps"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFD300),
                                  side: const BorderSide(
                                    color: Color(0xFFFFD300),
                                  ),
                                ),
                              ),
                            ]
                          : []),
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
                            ? "No description provided."
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
                    color: Colors.grey.shade900.withValues(
                      alpha: Colors.grey.shade900.opacity * 0.5,
                    ),
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
                GestureDetector(
                  onTap: _openCommentsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
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
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white12,
                          child: Icon(
                            Icons.add,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Add a comment...",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_up, color: Colors.white38),
                      ],
                    ),
                  ),
                ),

                // Admin controls
                ...(_isAdmin
                    ? [
                        const Divider(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0057B7),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _editEvent,
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit Event"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _cancelEvent,
                                icon: const Icon(Icons.cancel),
                                label: const Text("Cancel Event"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _deleteEvent,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text("Delete Event Permanently"),
                        ),
                      ]
                    : []),
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
                            "Stage ${myRelayStages.join(", ")}",
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
              // Support section
              if (myRelayRoles.isNotEmpty) ...[
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
              // Marshalling section
              if (responseType == "marshalling") ...[
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
              const SizedBox(height: 12),
              Center(
                child: FilledButton.icon(
                  onPressed: _addRoleClicked,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Role"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show relay buttons for new response
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
    String? responseType,
    Map<String, int>? supportRoleCounts,
  }) {
    return InkWell(
      onTap: count > 0
          ? () {
              if (responseType != null) {
                _showParticipantsByType(label, responseType);
              }
            }
          : null,
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
    final roleCounts = supportRoleBreakdown();

    return [
      _buildParticipantLine(
        "🏃‍♀️ Running",
        runners.length,
        runners,
        responseType: 'running',
      ),
      _buildParticipantLine(
        "🦺 Stage 6 Marshals",
        volunteers.length,
        volunteers,
        responseType: 'marshalling',
      ),
      _buildParticipantLine(
        "⚙️ Support Crew",
        supporters.length,
        supporters,
        responseType: 'supporting',
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
    } else if (choice == 'support') {
      await showRelaySupportingDialog();
    }
  }

  Future<void> showRelayRunningDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RelayRunningDialog(
        relayStages: relayStages,
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
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _contactHost() async {
    final hostUserId = widget.event.createdBy ?? supabase.auth.currentUser?.id;
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
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from("event_comments").insert({
      "event_id": widget.event.id,
      "user_id": user.id,
      "comment": comment,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }

  Future<void> _openCommentsSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        eventId: widget.event.id,
        commentController: commentController,
        onCommentSubmitted: _submitComment,
      ),
    );
  }

  Future<void> _editEvent() async {
    // Navigate to edit page (you'll need to create this or reuse create page)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Edit feature coming soon!")));
    // TODO: Navigate to AdminCreateEventPage in edit mode
    // Navigator.pushNamed(context, '/admin-edit-event', arguments: widget.event);
  }

  Future<void> _cancelEvent() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Event?"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await supabase
        .from("club_events")
        .update({
          "is_cancelled": true,
          "cancel_reason": reasonController.text.trim(),
        })
        .eq("id", widget.event.id);

    // Notify all participants about cancellation
    await NotificationService.notifyEventParticipants(
      eventId: widget.event.id,
      title: 'Event Cancelled',
      body: '${widget.event.title} has been cancelled',
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Event Permanently?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Notify all participants about deletion
    await NotificationService.notifyEventParticipants(
      eventId: widget.event.id,
      title: 'Event Deleted',
      body: '${widget.event.title} has been removed from the calendar',
    );

    await supabase.from("club_events").delete().eq("id", widget.event.id);
    Navigator.pop(context);
  }

  Future<void> _showParticipantsByType(
    String title,
    String responseType,
  ) async {
    final attendees = await getRespondersWithNames(
      eventId: widget.event.id,
      responseType: responseType,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: attendees.isEmpty
              ? const Center(
                  child: Text(
                    "No participants yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    final a = attendees[i];
                    final name = a['fullName'] as String? ?? 'Unknown runner';
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

  Future<Map<String, String>> fetchNamesForIds(Set<String> userIds) async {
    return super.fetchNamesForIds(userIds);
  }
}
