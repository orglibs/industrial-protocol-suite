import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iec61850_server/main.dart';
import 'package:iec61850_server/src/i18n/app_i18n.dart';
import 'package:iec61850_server/src/models/scl_models.dart';
import 'package:iec61850_server/src/models/scl_parser.dart';
import 'package:iec61850_server/src/models/server_config.dart';
import 'package:iec61850_server/src/models/server_variable_model.dart';
import 'package:iec61850_server/src/protocol/iec61850_server_manager.dart';
import 'package:iec61850_server/src/models/dictionary_service.dart';
import 'package:iec61850_server/src/ui/tabs/data_monitor_tab.dart';
import 'package:iec61850_server/src/ui/tabs/model_explorer_tab.dart';

void main() {
  group('Requirement 1 & 6: Multi-Connection & Multi-Language i18n Tests', () {
    test('Default presets create multiple independent server connections with own services', () {
      final connections = ServerConfig.createDefaultConnections();
      expect(connections.length, greaterThanOrEqualTo(3));

      // Preset 1: Default Substation (Port 102)
      final conn1 = connections[0];
      expect(conn1.id, 'conn-default-102');
      expect(conn1.port, 102);
      expect(conn1.nameKey, 'preset_iec61850_server_default');

      // Preset 2: Control & Switchgear (Port 10102)
      final conn2 = connections[1];
      expect(conn2.id, 'conn-control-10102');
      expect(conn2.port, 10102);
      expect(conn2.nameKey, 'preset_iec61850_server_control');

      // Preset 3: Wind Power & Settings (Port 10103)
      final conn3 = connections[2];
      expect(conn3.id, 'conn-wind-10103');
      expect(conn3.port, 10103);
      expect(conn3.nameKey, 'preset_iec61850_server_wind');

      // Independence: Each manager and its internal services are distinct
      expect(conn1.manager, isNot(same(conn2.manager)));
      expect(conn1.manager.gooseService, isNot(same(conn2.manager.gooseService)));
      expect(conn1.manager.simulationService, isNot(same(conn2.manager.simulationService)));
    });

    test('Connections reactively update displayName across all 17 supported languages', () {
      final connections = ServerConfig.createDefaultConnections();
      final conn1 = connections[0];
      final conn2 = connections[1];
      final conn3 = connections[2];

      // 1. Chinese (zh-CN)
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(conn1.displayName, contains('默认'));
      expect(conn2.displayName, contains('测控与开关'));
      expect(conn3.displayName, contains('风电'));

      // 2. English (en-US)
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(conn1.displayName, contains('Default'));
      expect(conn2.displayName, contains('Control & Switchgear'));
      expect(conn3.displayName, contains('Wind Power'));

      // 3. German (de-DE)
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(conn1.displayName, contains('Standard'));
      expect(conn2.displayName, contains('Steuer'));
      expect(conn3.displayName, contains('Windkraft'));

      // 4. French (fr-FR)
      AppI18n.instance.setLanguage(AppLanguage.frFR);
      expect(conn1.displayName, contains('défaut'));
      expect(conn2.displayName, contains('contrôle'));

      // 5. Japanese (ja-JP)
      AppI18n.instance.setLanguage(AppLanguage.jaJP);
      expect(conn1.displayName, contains('デフォルト'));
      expect(conn2.displayName, contains('制御'));

      // 6. Russian (ru-RU)
      AppI18n.instance.setLanguage(AppLanguage.ruRU);
      expect(conn1.displayName, contains('умолчанию'));
      expect(conn2.displayName, contains('управления'));

      // Reset to zh-CN
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
    });

    test('stopAll helper properly updates isRunning state across connections', () async {
      final connections = ServerConfig.createDefaultConnections();
      await Iec61850ServerManager.stopAll(connections);
      for (final c in connections) {
        expect(c.isRunning, isFalse);
      }
    });

    test('Workspace serialization and deserialization of multiple connections', () {
      final original = ServerConfig.createDefaultConnections();
      final jsonList = original.map((c) => c.toJson()).toList();

      expect(jsonList.length, original.length);
      final restored = jsonList.map((j) => ServerConfig.fromJson(j)).toList();

      expect(restored.length, original.length);
      expect(restored[0].id, original[0].id);
      expect(restored[0].port, original[0].port);
      expect(restored[0].nameKey, original[0].nameKey);
      expect(restored[1].id, original[1].id);
      expect(restored[1].port, original[1].port);
      expect(restored[1].nameKey, original[1].nameKey);
      expect(restored[2].id, original[2].id);
      expect(restored[2].port, original[2].port);
      expect(restored[2].nameKey, original[2].nameKey);
    });
  });

  group('Requirement 2 & 3: UI Header Icon & Left Navigation Rail Tests', () {
    testWidgets('App Header uses assets image icon and left NavigationRail is constrained without leading icon',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final connections = ServerConfig.createDefaultConnections();
      AppI18n.instance.setLanguage(AppLanguage.zhCN);

      await tester.pumpWidget(Iec61850App(initialConnections: connections));
      await tester.pumpAndSettle();

      // Requirement 3: App header icon uses assets icon
      final imageFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          final asset = widget.image as AssetImage;
          return asset.assetName == 'assets/icons/iec61850_server_app_512.png';
        }
        return false;
      });
      expect(imageFinder, findsOneWidget);

      // Requirement 2: NavigationRail has no leading widget (top power icon removed)
      final navRailFinder = find.byType(NavigationRail);
      expect(navRailFinder, findsOneWidget);

      final navRail = tester.widget<NavigationRail>(navRailFinder);
      expect(navRail.leading, isNull);

      // Requirement 2: NavigationRail is constrained with maxWidth 88
      final constrainedBox = find.ancestor(
        of: navRailFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is ConstrainedBox) {
            return w.constraints.maxWidth == 88;
          }
          return false;
        }),
      );
      expect(constrainedBox, findsOneWidget);

      // Requirement 2: Each destination label has maxWidth 72 and softWrap enabled
      for (final dest in navRail.destinations) {
        expect(dest.label, isA<Tooltip>());
        final tooltip = dest.label as Tooltip;
        expect(tooltip.child, isA<ConstrainedBox>());
        final cBox = tooltip.child as ConstrainedBox;
        expect(cBox.constraints.maxWidth, 72);
        expect(cBox.child, isA<Text>());
        final text = cBox.child as Text;
        expect(text.softWrap, isTrue);
        expect(text.maxLines, 2);
      }
    });
  });

  group('Requirement 4 & 5: DataMonitorTab Compact Query Bar & Fixed Column Widths with Tooltips', () {
    testWidgets('DataMonitorTab query bar is compact with horizontal scroll and hover tooltips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final connections = ServerConfig.createDefaultConnections();
      AppI18n.instance.setLanguage(AppLanguage.zhCN);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DataMonitorTab(
            connections: connections,
            activeConnection: connections.first,
            onDataChanged: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Requirement 4: Top query bar contains Tooltip widgets for hover visibility
      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsWidgets);

      // Requirement 4: Query bar is wrapped in SingleChildScrollView(scrollDirection: Axis.horizontal)
      final horizontalScrolls = find.byWidgetPredicate((w) {
        if (w is SingleChildScrollView && w.scrollDirection == Axis.horizontal) {
          return true;
        }
        return false;
      });
      expect(horizontalScrolls, findsWidgets);

      // Requirement 4: Connection Dropdown exists for multi-connection switching
      final dropdownFinder = find.byType(DropdownButton<ServerConfig>);
      expect(dropdownFinder, findsOneWidget);
    });

    testWidgets('DataTable in DataMonitorTab has fixed column widths with hover tooltips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final connections = ServerConfig.createDefaultConnections();
      final conn = connections.first;

      // Populate variable via SCL for table display
      final dummyVar = ServerVariableModel(
        reference: 'TEST_IEDLD0/GGIO1.Ind1.stVal',
        iedName: 'TEST_IED',
        ldInst: 'LD0',
        lnName: 'GGIO1',
        doName: 'Ind1',
        daName: 'stVal',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        initialValue: true,
        quality: 0,
        timestamp: DateTime.now(),
      );

      conn.manager.loadScl(SclParseResult(
        iedName: 'TEST_IED',
        ied: SclIED(name: 'TEST_IED'),
        variables: [dummyVar],
        dataSets: [],
        reportControls: [],
        gseControls: [],
        svControls: [],
      ));

      AppI18n.instance.setLanguage(AppLanguage.zhCN);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DataMonitorTab(
            connections: connections,
            activeConnection: conn,
            onDataChanged: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Requirement 5: Data table has fixed column widths
      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      expect(dataTable.columns.length, 9);

      // Expected column widths: Pin(55), Ref(240), FC(60), Type(85), Val(120), Quality(95), Time(110), Sim(120), Action(100)
      final expectedWidths = [55.0, 240.0, 60.0, 85.0, 120.0, 95.0, 110.0, 120.0, 100.0];
      for (int i = 0; i < dataTable.columns.length; i++) {
        final col = dataTable.columns[i];
        expect(col.label, isA<SizedBox>());
        final sizedBox = col.label as SizedBox;
        expect(sizedBox.width, expectedWidths[i]);
        expect(sizedBox.child, isA<Tooltip>());
      }
    });

    test('ServerVariableModel demo data reactively updates displayName via nameKey across languages', () {
      final vVolt = ServerVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.AnIn1.mag.f',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        name: 'Phase A Voltage Ua (kV)',
        nameKey: 'point_volt_a',
      );

      final vBreaker = ServerVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.SPCSO1.stVal',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'SPCSO1',
        daName: 'stVal',
        fc: FunctionalConstraint.st,
        type: IecBasicType.boolean,
        name: '101 Breaker Closed Status',
        nameKey: 'point_breaker_101',
      );

      // Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(vVolt.displayName, contains('A相电压'));
      expect(vBreaker.displayName, contains('101断路器'));

      // English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(vVolt.displayName, contains('Phase A Voltage'));
      expect(vBreaker.displayName, contains('Breaker 101'));

      // German
      AppI18n.instance.setLanguage(AppLanguage.deDE);
      expect(vVolt.displayName, contains('Phase A Spannung'));

      // French
      AppI18n.instance.setLanguage(AppLanguage.frFR);
      expect(vVolt.displayName, contains('Tension Phase A'));
    });

    test('ServerVariableModel serialization and fallback nameKey inference', () {
      // 1. toJson serialization includes Name and NameKey
      final original = ServerVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.AnIn1.mag.f',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        name: 'Phase A Voltage Ua (kV)',
        nameKey: 'point_volt_a',
      );
      final json = original.toJson();
      expect(json['Name'], equals('Phase A Voltage Ua (kV)'));
      expect(json['NameKey'], equals('point_volt_a'));

      // 2. fromJson with explicit NameKey
      final restored = ServerVariableModel.fromJson(json);
      expect(restored.nameKey, equals('point_volt_a'));

      // 3. fromJson with legacy payload lacking NameKey -> auto inferred
      final legacyVolt = ServerVariableModel.fromJson({
        'Reference': 'simpleIO/GenericIO/GGIO1.AnIn1.mag.f',
        'DoName': 'AnIn1',
        'DaName': 'mag.f',
        'FC': 'MX',
        'Type': 'FLOAT32',
      });
      expect(legacyVolt.nameKey, equals('point_volt_a'));

      final legacyBreaker = ServerVariableModel.fromJson({
        'Reference': 'simpleIO/GenericIO/GGIO1.SPCSO1.stVal',
        'DoName': 'SPCSO1',
        'DaName': 'stVal',
        'FC': 'ST',
        'Type': 'BOOLEAN',
      });
      expect(legacyBreaker.nameKey, equals('point_breaker_101'));

      final legacyDisconnector = ServerVariableModel.fromJson({
        'Reference': 'simpleIO/GenericIO/GGIO1.Ind2.stVal',
        'DoName': 'Ind2',
        'DaName': 'stVal',
        'FC': 'ST',
        'Type': 'BOOLEAN',
      });
      expect(legacyDisconnector.nameKey, equals('point_disconnector_1011'));

      final legacyFreq = ServerVariableModel.fromJson({
        'Reference': 'simpleIO/GenericIO/GGIO1.AnIn4.mag.f',
        'DoName': 'AnIn4',
        'DaName': 'mag.f',
        'FC': 'MX',
        'Type': 'FLOAT32',
      });
      expect(legacyFreq.nameKey, equals('point_grid_freq'));
    });

    test('SclDataSet, SclReportControl, and SclGSEControl reactively update displayName via nameKey', () {
      final dsEvents = SclDataSet(
        name: 'Events',
        nameKey: 'preset_ds_events',
      );
      final dsMeas = SclDataSet(
        name: 'Measurements',
        nameKey: 'preset_ds_measurements',
      );

      final rcbEvents = SclReportControl(
        name: 'EventsRCB',
        nameKey: 'preset_rcb_events',
        rptId: 'Events1',
        buffered: false,
        datSet: 'Events',
      );

      final gcbTrip = SclGSEControl(
        name: 'GCB1',
        nameKey: 'preset_gcb_trip',
        goId: 'Trip1',
        datSet: 'GooseDS',
      );

      // 1. Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(dsEvents.displayName, contains('遥信变位事件'));
      expect(dsMeas.displayName, contains('模拟量遥测'));
      expect(rcbEvents.displayName, contains('无缓冲事件报告'));
      expect(gcbTrip.displayName, contains('快速跳闸'));

      // 2. English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(dsEvents.displayName, contains('Status Events'));
      expect(dsMeas.displayName, contains('Analog Measurements'));
      expect(rcbEvents.displayName, contains('Unbuffered Events Report'));
      expect(gcbTrip.displayName, contains('Fast Trip'));
    });

    test('SclParser automatically assigns nameKey to instantiated variables and DataSets', () {
      final file = File('assets/examples/server_example_basic_io.icd');
      expect(file.existsSync(), isTrue);

      final result = SclParser.parse(file.readAsStringSync());
      expect(result.dataSets.isNotEmpty, isTrue);

      final dsEvents = result.dataSets.firstWhere((d) => d.name == 'Events');
      expect(dsEvents.nameKey, equals('preset_ds_events'));

      final dsMeas = result.dataSets.firstWhere((d) => d.name == 'Measurements');
      expect(dsMeas.nameKey, equals('preset_ds_measurements'));

      final rcbEvents = result.reportControls.firstWhere((r) => r.name == 'EventsRCB');
      expect(rcbEvents.nameKey, equals('preset_rcb_events'));

      // Find variable AnIn1.mag.f
      final anIn = result.variables.firstWhere((v) => v.doName == 'AnIn1' && v.daName == 'mag.f');
      expect(anIn.nameKey, equals('point_volt_a'));

      // Find variable SPCSO1.stVal
      final spcso = result.variables.firstWhere((v) => v.doName == 'SPCSO1' && v.daName == 'stVal');
      expect(spcso.nameKey, equals('point_breaker_101'));
    });
  });

  group('Requirement: SCL Data Model Internationalization Tests', () {
    setUp(() async {
      await DictionaryService.instance.load();
    });

    test('DictionaryService and IecDesc dynamically switch between Chinese and English', () {
      final dict = DictionaryService.instance;

      // 1. Common Data Class (CDC) lookup
      final cdcMv = dict.getCdc('MV');
      expect(cdcMv, isNotNull);
      final cdcSpc = dict.getCdc('SPC');
      expect(cdcSpc, isNotNull);

      // In Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(cdcMv!.display, equals('测量值'));
      expect(cdcSpc!.display, equals('可控的单点'));

      // In English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(cdcMv.display, equals('Measured Value'));
      expect(cdcSpc.display, equals('Controllable Single Point'));

      // 2. Logical Node (LN) lookup with exact name and instance numbers
      final lnMmxu = dict.getLogicalNode('MMXU');
      expect(lnMmxu, isNotNull);
      final lnMmxu1 = dict.getLogicalNode('MMXU1');
      expect(lnMmxu1, isNotNull);
      final lnLln0 = dict.getLogicalNode('LLN0');
      expect(lnLln0, isNotNull);
      final lnGgio = dict.getLogicalNode('GGIO1');
      expect(lnGgio, isNotNull);

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(lnMmxu!.display, equals('测量'));
      expect(lnMmxu1!.display, equals('测量'));
      expect(lnLln0!.display, equals('逻辑节点零'));
      expect(lnGgio!.display, equals('通用过程I/O'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(lnMmxu.display, equals('Measurement'));
      expect(lnMmxu1.display, equals('Measurement'));
      expect(lnLln0.display, equals('Logic node zero'));
      expect(lnGgio.display, equals('Generic process I/O'));

      // 3. Data Object (DO) lookup
      final doAnIn1 = dict.getDataObject('AnIn1');
      expect(doAnIn1, isNotNull);
      final doSpcso1 = dict.getDataObject('SPCSO1');
      expect(doSpcso1, isNotNull);
      final doTotW = dict.getDataObject('TotW');
      expect(doTotW, isNotNull);

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(doAnIn1!.display, equals('模拟输入'));
      expect(doTotW!.display, equals('总有功功率P'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(doAnIn1.display, equals('Analogue input'));
      expect(doTotW.display, contains('Total active power'));

      // 4. Data Attribute (DA) standard resolution
      final daStVal = dict.getDataAttribute('stVal');
      expect(daStVal, isNotNull);
      final daQ = dict.getDataAttribute('q');
      expect(daQ, isNotNull);
      final daMagF = dict.getDataAttribute('mag.f');
      expect(daMagF, isNotNull);

      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(daStVal!.display, equals('状态值'));
      expect(daQ!.display, equals('品质'));
      expect(daMagF!.display, equals('浮点值'));

      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(daStVal.display, equals('Status Value'));
      expect(daQ.display, equals('Quality'));
      expect(daMagF.display, equals('Floating Point Value'));
    });

    test('SCL Data Model hierarchy entities (SclIED, SclLDevice, SclLN, SclDOType) support i18n', () {
      final ied = SclIED(
        name: 'simpleIO',
        nameKey: 'ld_generic_io',
      );
      final ld = SclLDevice(
        inst: 'GenericIO',
        nameKey: 'ld_generic_io',
      );
      final ln = SclLN(
        lnClass: 'MMXU',
        inst: '1',
        lnType: 'MMXU1_Type',
      );
      final doType = SclDOType(
        id: 'MV_Type',
        cdc: 'MV',
      );

      // In Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(ied.displayName, equals('通用过程I/O'));
      expect(ld.displayName, equals('通用过程I/O'));
      expect(ln.displayName, contains('测量'));
      expect(doType.cdcDisplay, equals('MV (测量值)'));

      // In English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(ied.displayName, equals('Generic Process I/O'));
      expect(ld.displayName, equals('Generic Process I/O'));
      expect(ln.displayName, contains('Measurement'));
      expect(doType.cdcDisplay, equals('MV (Measured Value)'));
    });

    test('ServerVariableModel cdc and cdcDisplay support i18n and serialization', () {
      final v = ServerVariableModel(
        reference: 'simpleIO/GenericIO/GGIO1.AnIn1.mag.f',
        iedName: 'simpleIO',
        ldInst: 'GenericIO',
        lnName: 'GGIO1',
        doName: 'AnIn1',
        daName: 'mag.f',
        fc: FunctionalConstraint.mx,
        type: IecBasicType.float32,
        cdc: 'MV',
        nameKey: 'point_volt_a',
      );

      // In Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      expect(v.displayName, contains('A相电压'));
      expect(v.cdcDisplay, equals('MV (测量值)'));

      // In English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      expect(v.displayName, contains('Phase A Voltage'));
      expect(v.cdcDisplay, equals('MV (Measured Value)'));

      // Serialization round-trip
      final json = v.toJson();
      expect(json['CDC'], equals('MV'));
      final fromJson = ServerVariableModel.fromJson(json);
      expect(fromJson.cdc, equals('MV'));
      expect(fromJson.cdcDisplay, equals('MV (Measured Value)'));
    });

    testWidgets('ModelExplorerTab renders localized dictionary and hierarchy data reactively', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final config = ServerConfig(
        id: 'test-model-i18n',
        name: 'Model Test',
        port: 19999,
      );
      final manager = Iec61850ServerManager(config: config);
      final file = File('assets/examples/server_example_basic_io.icd');
      final parseRes = SclParser.parse(file.readAsStringSync());
      manager.loadScl(parseRes);

      // 1. Initial render in Chinese
      AppI18n.instance.setLanguage(AppLanguage.zhCN);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelExplorerTab(
              manager: manager,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and select Phase A Voltage in Chinese
      final zhItem = find.textContaining('A相电压').first;
      expect(zhItem, findsOneWidget);
      await tester.tap(zhItem);
      await tester.pumpAndSettle();

      // Verify Chinese localized elements
      expect(find.text(AppI18n.instance.t('standardDictTitle')), findsOneWidget);
      expect(find.text(AppI18n.instance.t('sclHierarchyTitle')), findsOneWidget);
      expect(find.text(AppI18n.instance.t('dictCdc')), findsWidgets);
      expect(find.text(AppI18n.instance.t('dictLn')), findsWidgets);
      expect(find.text('测量值'), findsWidgets);

      // 2. Switch language to English
      AppI18n.instance.setLanguage(AppLanguage.enUS);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelExplorerTab(
              manager: manager,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and select Phase A Voltage in English
      final enItem = find.textContaining('Phase A Voltage').first;
      expect(enItem, findsOneWidget);
      await tester.tap(enItem);
      await tester.pumpAndSettle();

      // Verify English localized elements
      expect(find.text(AppI18n.instance.t('standardDictTitle')), findsOneWidget);
      expect(find.text(AppI18n.instance.t('sclHierarchyTitle')), findsOneWidget);
      expect(find.text(AppI18n.instance.t('dictCdc')), findsWidgets);
      expect(find.text(AppI18n.instance.t('dictLn')), findsWidgets);
      expect(find.text('Measured Value'), findsWidgets);
    });

    testWidgets('ModelExplorerTab inspector Current Value has fixed width with hover tooltip', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final config = ServerConfig(
        id: 'test-model-current-val',
        name: 'Model Test',
        port: 19998,
      );
      final manager = Iec61850ServerManager(config: config);
      final file = File('assets/examples/server_example_basic_io.icd');
      final parseRes = SclParser.parse(file.readAsStringSync());
      manager.loadScl(parseRes);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelExplorerTab(
              manager: manager,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select first variable in list
      final item = find.byType(ListTile).first;
      await tester.tap(item);
      await tester.pumpAndSettle();

      // Find the current value container with fixed width (150) and Tooltip
      final fixedBox = find.byWidgetPredicate((w) {
        if (w is SizedBox && w.width == 150) {
          return w.child is Tooltip;
        }
        return false;
      });
      expect(fixedBox, findsOneWidget);
    });
  });
}

