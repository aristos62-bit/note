import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'appointment_detail_screen.dart';

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ItemListScreen(
      itemType: ItemType.appointment,
      title: 'Ραντεβού',
      detailScreenBuilder: (context, item, {bool isNew = false}) {
        return AppointmentDetailScreen(itemId: item.id, isNew: isNew);
      },
    );
  }
}