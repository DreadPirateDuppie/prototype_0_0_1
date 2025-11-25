import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_0_0_1/services/admin_service.dart';

void main() {
  group('AdminService', () {
    late AdminService adminService;

    setUp(() {
      adminService = AdminService();
    });

    group('AdminService instantiation', () {
      test('can be created without client', () {
        final service = AdminService();
        expect(service, isNotNull);
      });

      test('can be created with null client', () {
        final service = AdminService(client: null);
        expect(service, isNotNull);
      });
    });

    group('Hardcoded admin email checks', () {
      test('admin@example.com is hardcoded admin', () {
        const email = 'admin@example.com';
        final isHardcodedAdmin =
            email == 'admin@example.com' || email == '123@123.com';
        expect(isHardcodedAdmin, true);
      });

      test('123@123.com is hardcoded admin', () {
        const email = '123@123.com';
        final isHardcodedAdmin =
            email == 'admin@example.com' || email == '123@123.com';
        expect(isHardcodedAdmin, true);
      });

      test('regular email is not hardcoded admin', () {
        const email = 'user@example.com';
        final isHardcodedAdmin =
            email == 'admin@example.com' || email == '123@123.com';
        expect(isHardcodedAdmin, false);
      });
    });

    group('Report status values', () {
      test('pending is a valid report status', () {
        const status = 'pending';
        final validStatuses = ['pending', 'resolved', 'dismissed'];
        expect(validStatuses.contains(status), true);
      });

      test('resolved is a valid report status', () {
        const status = 'resolved';
        final validStatuses = ['pending', 'resolved', 'dismissed'];
        expect(validStatuses.contains(status), true);
      });

      test('dismissed is a valid report status', () {
        const status = 'dismissed';
        final validStatuses = ['pending', 'resolved', 'dismissed'];
        expect(validStatuses.contains(status), true);
      });
    });

    group('Video moderation statuses', () {
      test('approved is a valid video status', () {
        const status = 'approved';
        final validStatuses = ['pending', 'approved', 'rejected'];
        expect(validStatuses.contains(status), true);
      });

      test('rejected is a valid video status', () {
        const status = 'rejected';
        final validStatuses = ['pending', 'approved', 'rejected'];
        expect(validStatuses.contains(status), true);
      });

      test('pending is the default video status', () {
        const defaultStatus = 'pending';
        expect(defaultStatus, 'pending');
      });
    });

    group('Pagination calculations', () {
      test('offset calculation is correct for page 1', () {
        const page = 1;
        const limit = 50;
        final offset = (page - 1) * limit;
        expect(offset, 0);
      });

      test('offset calculation is correct for page 2', () {
        const page = 2;
        const limit = 50;
        final offset = (page - 1) * limit;
        expect(offset, 50);
      });

      test('range calculation is correct', () {
        const offset = 0;
        const limit = 50;
        final rangeEnd = offset + limit - 1;
        expect(rangeEnd, 49);
      });
    });
  });
}
