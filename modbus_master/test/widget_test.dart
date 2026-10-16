import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modbus_master/src/protocol/modbus_data_types.dart';
import 'package:modbus_master/src/models/register_model.dart';

void main() {
  testWidgets('RegisterModel formats display value correctly in UI widget', (WidgetTester tester) async {
    final reg = RegisterModel(
      address: 0,
      rawValue: 0x1234,
      valueFormat: RegisterDataFormat.hex16,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(reg.getDisplayValue()),
        ),
      ),
    );

    expect(find.text('0x1234'), findsOneWidget);
  });
}
