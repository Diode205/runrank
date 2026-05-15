// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/events/event_details_simple.dart';
import 'package:runrank/widgets/events/event_details_race.dart';
import 'package:runrank/widgets/events/event_details_relay.dart';

/// EventDetailsPage routes to the appropriate event-type specific page based on event type.
///
/// Event Types:
/// - Group 1 (Simple): Training, Training_1, Training_2, NRR training sessions, Special_Event, Social_Run, Parkrun_Tourism, Meet_&_Drink, Swim_or_Cycle, Others
/// - Group 2 (Race): Race, Handicap_Series, One_Mile_Handicap
/// - Group 3 (Relay): Relay
class EventDetailsPage extends StatelessWidget {
  final ClubEvent event;
  final bool openHostChat;

  const EventDetailsPage({
    super.key,
    required this.event,
    this.openHostChat = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = event.eventType.trim().toLowerCase().replaceAll(' ', '_');

    switch (type) {
      case 'training':
      case 'training_1':
      case 'training_2':
      case 'recovery_monday':
      case 'mousehold_monday':
      case 'tuesday_efforts_1':
      case 'tuesday_efforts_2':
      case 'tuesday_efforts':
      case 'efforts_tuesday':
      case 'road_run_thursday':
      case 'track_session':
      case 'coached_tuesday':
      case 'road_route_thursday':
      case 'paul_evans_session':
      case 'special_event':
      case 'social_run':
      case 'parkrun_tourism':
      case 'meet_&_drink':
      case 'swim_or_cycle':
      case 'others':
        return SimpleEventDetailsPage(event: event, openHostChat: openHostChat);
      case 'race':
      case 'cross_country':
      case 'handicap_series':
      case 'one_mile_handicap':
        return RaceEventDetailsPage(event: event, openHostChat: openHostChat);
      case 'relay':
        return RelayEventDetailsPage(event: event, openHostChat: openHostChat);
      default:
        return Scaffold(
          appBar: AppBar(title: const Text('Event Details')),
          body: Center(child: Text('Unknown event type: $type')),
        );
    }
  }
}
