// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/events/event_details_simple.dart';
import 'package:runrank/widgets/events/event_details_race.dart';
import 'package:runrank/widgets/events/event_details_relay.dart';

/// EventDetailsPage routes to the appropriate event-type specific page based on event type.
///
/// Event Types:
/// - Group 1 (Simple): Training_1, Training_2, Special_Event, Social_Run, Meet_&_Drink, Swim_or_Cycle, Others
/// - Group 2 (Race): Race, Handicap_Series
/// - Group 3 (Relay): Relay
class EventDetailsPage extends StatelessWidget {
  final ClubEvent event;

  const EventDetailsPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event.eventType.toLowerCase();

    switch (type) {
      case 'training_1':
      case 'training_2':
      case 'special_event':
      case 'social_run':
      case 'meet_&_drink':
      case 'swim_or_cycle':
      case 'others':
        return SimpleEventDetailsPage(event: event);
      case 'race':
      case 'cross_country':
      case 'handicap_series':
        return RaceEventDetailsPage(event: event);
      case 'relay':
        return RelayEventDetailsPage(event: event);
      default:
        return Scaffold(
          appBar: AppBar(title: const Text('Event Details')),
          body: Center(child: Text('Unknown event type: $type')),
        );
    }
  }
}
