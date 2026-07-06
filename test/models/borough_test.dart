import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:prototype_0_0_1/models/borough.dart';
import 'package:prototype_0_0_1/widgets/territory_polygon_layer.dart';

void main() {
  group('BoroughState', () {
    Map<String, dynamic> baseRow({
      String? crewId,
      double defense = 100.0,
      double destab = 0.0,
    }) =>
        {
          'borough_id': 'southwark',
          'name': 'Southwark',
          'polygon': [
            [51.508, -0.104],
            [51.505, -0.078],
            [51.421, -0.065],
            [51.472, -0.111],
          ],
          'owning_crew_id': crewId,
          'owning_crew_name': crewId != null ? 'Peckham Pushers' : null,
          'owning_crew_color': crewId != null ? '#ff8800' : null,
          'defense_score': defense,
          'destabilization_score': destab,
          'last_captured_at':
              crewId != null ? '2026-07-01T12:00:00.000Z' : null,
        };

    group('fromMap', () {
      test('parses an owned borough row from the borough_states view', () {
        final state = BoroughState.fromMap(
            baseRow(crewId: 'crew-1', defense: 150, destab: 30));

        expect(state.boroughId, 'southwark');
        expect(state.name, 'Southwark');
        expect(state.isOwned, isTrue);
        expect(state.owningCrewId, 'crew-1');
        expect(state.owningCrewName, 'Peckham Pushers');
        expect(state.owningCrewColorHex, '#ff8800');
        expect(state.defenseScore, 150.0);
        expect(state.destabilizationScore, 30.0);
        expect(state.lastCapturedAt, isNotNull);
        expect(state.polygon.length, 4);
        expect(state.polygon.first, const LatLng(51.508, -0.104));
      });

      test('parses an unowned borough row', () {
        final state = BoroughState.fromMap(baseRow());
        expect(state.isOwned, isFalse);
        expect(state.owningCrewColorHex, isNull);
        expect(state.lastCapturedAt, isNull);
      });

      test('handles integer scores and malformed polygon vertices', () {
        final row = baseRow();
        row['defense_score'] = 100; // int, not double
        row['destabilization_score'] = 25;
        row['polygon'] = [
          [51.5, -0.1],
          [51.4], // too short: skipped
          'garbage', // wrong type: skipped
          [51.45, -0.05],
        ];
        final state = BoroughState.fromMap(row);
        expect(state.defenseScore, 100.0);
        expect(state.destabilizationScore, 25.0);
        expect(state.polygon.length, 2);
      });

      test('handles a null polygon without throwing', () {
        final row = baseRow();
        row['polygon'] = null;
        final state = BoroughState.fromMap(row);
        expect(state.polygon, isEmpty);
      });
    });

    group('fragility (Fragile State metric)', () {
      test('is 0 when there is no destabilization', () {
        final state =
            BoroughState.fromMap(baseRow(crewId: 'c', defense: 100));
        expect(state.fragility, 0.0);
        expect(state.isCapturable, isFalse);
      });

      test('is proportional to destabilization vs defense', () {
        final state = BoroughState.fromMap(
            baseRow(crewId: 'c', defense: 200, destab: 50));
        expect(state.fragility, 0.25);
      });

      test('clamps at 1.0 when destabilization exceeds defense', () {
        final state = BoroughState.fromMap(
            baseRow(crewId: 'c', defense: 100, destab: 250));
        expect(state.fragility, 1.0);
        expect(state.isCapturable, isTrue);
      });

      test('zero defense with destabilization is fully fragile', () {
        final state =
            BoroughState.fromMap(baseRow(crewId: 'c', defense: 0, destab: 5));
        expect(state.fragility, 1.0);
      });

      test('zero defense with zero destabilization is stable', () {
        final state =
            BoroughState.fromMap(baseRow(crewId: 'c', defense: 0, destab: 0));
        expect(state.fragility, 0.0);
      });
    });

    group('fillOpacityFor (opacity fades as destabilization rises)', () {
      test('stable borough renders at max opacity', () {
        expect(BoroughState.fillOpacityFor(0.0), 0.35);
      });

      test('fully destabilized borough renders at min opacity', () {
        expect(BoroughState.fillOpacityFor(1.0), closeTo(0.05, 1e-9));
      });

      test('opacity decreases monotonically with fragility', () {
        final quarter = BoroughState.fillOpacityFor(0.25);
        final half = BoroughState.fillOpacityFor(0.5);
        final threeQ = BoroughState.fillOpacityFor(0.75);
        expect(quarter, greaterThan(half));
        expect(half, greaterThan(threeQ));
      });

      test('out-of-range fragility is clamped', () {
        expect(BoroughState.fillOpacityFor(-1.0), 0.35);
        expect(BoroughState.fillOpacityFor(5.0), closeTo(0.05, 1e-9));
      });

      test('instance getter uses the state fragility', () {
        final state = BoroughState.fromMap(
            baseRow(crewId: 'c', defense: 100, destab: 100));
        expect(state.fillOpacity, closeTo(0.05, 1e-9));
      });
    });
  });

  group('TerritoryPolygonLayer.parseCrewColor', () {
    test('parses a #RRGGBB hex string', () {
      expect(TerritoryPolygonLayer.parseCrewColor('#ff8800'),
          const Color(0xFFFF8800));
    });

    test('parses without a leading hash', () {
      expect(TerritoryPolygonLayer.parseCrewColor('00ff41'),
          const Color(0xFF00FF41));
    });

    test('falls back to matrix green for null or invalid values', () {
      const fallback = Color(0xFF00FF41);
      expect(TerritoryPolygonLayer.parseCrewColor(null), fallback);
      expect(TerritoryPolygonLayer.parseCrewColor('#fff'), fallback);
      expect(TerritoryPolygonLayer.parseCrewColor('notacolor'), fallback);
    });
  });
}
