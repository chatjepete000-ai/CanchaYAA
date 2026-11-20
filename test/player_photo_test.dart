import 'package:cancha_ya/features/teams/domain/player_photo.dart';
import 'package:cancha_ya/features/teams/domain/team_lineup.dart';
import 'package:cancha_ya/features/teams/domain/team_models.dart';
import 'package:cancha_ya/features/teams/presentation/face_photo_capture_screen.dart';
import 'package:cancha_ya/features/teams/presentation/widgets/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = 'https://res.cloudinary.com/ns45i2wp/image/upload/v1/face.jpg';

// Selfie vertical de 1080 x 1440.
const _image = Size(1080, 1440);

DetectedFace _face(
  double left,
  double top,
  double size, {
  double? yaw,
  double? roll,
}) {
  return DetectedFace(
    box: Rect.fromLTWH(left, top, size, size * 1.2),
    yaw: yaw,
    roll: roll,
  );
}

void main() {
  group('validación de la foto de cara', () {
    test('selfie centrada y cercana es válida', () {
      expect(
        evaluateFacePhoto(
          imageSize: _image,
          faces: [_face(290, 400, 500, yaw: 5, roll: -3)],
        ),
        FacePhotoIssue.none,
      );
    });

    test('sin cara se rechaza', () {
      expect(
        evaluateFacePhoto(imageSize: _image, faces: const []),
        FacePhotoIssue.noFace,
      );
    });

    test('dos personas se rechaza', () {
      expect(
        evaluateFacePhoto(
          imageSize: _image,
          faces: [_face(100, 400, 400), _face(600, 400, 400)],
        ),
        FacePhotoIssue.multipleFaces,
      );
    });

    test('cuerpo completo (cara pequeña) se rechaza', () {
      // Cara de 90 px en una foto de 1080 px de ancho: ~8 %.
      expect(
        evaluateFacePhoto(imageSize: _image, faces: [_face(495, 200, 90)]),
        FacePhotoIssue.tooFar,
      );
    });

    test('medio cuerpo se rechaza', () {
      // ~18 % del lado corto.
      expect(
        evaluateFacePhoto(imageSize: _image, faces: [_face(440, 300, 200)]),
        FacePhotoIssue.tooFar,
      );
    });

    test('cara pegada a la orilla se rechaza', () {
      expect(
        evaluateFacePhoto(imageSize: _image, faces: [_face(-100, 0, 400)]),
        FacePhotoIssue.notCentered,
      );
    });

    test('cabeza girada se rechaza', () {
      expect(
        evaluateFacePhoto(
          imageSize: _image,
          faces: [_face(290, 400, 500, yaw: 40)],
        ),
        FacePhotoIssue.turned,
      );
    });

    test('foto horizontal también se valida por el lado corto', () {
      expect(
        evaluateFacePhoto(
          imageSize: const Size(1440, 1080),
          faces: [_face(500, 250, 420)],
        ),
        FacePhotoIssue.none,
      );
    });

    test('cada problema tiene un mensaje en español', () {
      for (final issue in FacePhotoIssue.values) {
        expect(issue.message, isNotEmpty);
      }
      expect(FacePhotoIssue.tooFar.message, contains('cuerpo completo'));
    });
  });

  group('URLs de la foto', () {
    test('solo se aceptan fotos de la cuenta de CanchaYA', () {
      expect(isTrustedPlayerPhotoUrl(_photo), isTrue);
      expect(isTrustedPlayerPhotoUrl(''), isFalse);
      expect(
        isTrustedPlayerPhotoUrl('https://evil.example.com/face.jpg'),
        isFalse,
      );
      expect(
        isTrustedPlayerPhotoUrl(
          'http://res.cloudinary.com/ns45i2wp/image/upload/v1/face.jpg',
        ),
        isFalse,
      );
      expect(
        isTrustedPlayerPhotoUrl(
          'https://res.cloudinary.com/otra/image/upload/v1/face.jpg',
        ),
        isFalse,
      );
    });

    test('la miniatura se recorta en la cara con Cloudinary', () {
      expect(
        playerFaceThumbnailUrl(_photo, size: 120),
        'https://res.cloudinary.com/ns45i2wp/image/upload/'
        'c_thumb,g_face,w_120,h_120,z_0.75/v1/face.jpg',
      );
      expect(playerFaceThumbnailUrl('https://evil.example.com/x.jpg'), '');
    });

    test('inicial del jugador sin foto', () {
      expect(playerInitial('ángel'), 'Á');
      expect(playerInitial('  '), '?');
    });
  });

  group('modelos', () {
    test('la asignación guarda la foto solo si existe', () {
      const base = TeamAssignment(
        id: 'a',
        userId: 'u',
        teamId: 't',
        leagueId: 'l',
        tournamentId: 'tt',
        role: TeamAssignmentRole.player,
        status: AssignmentStatus.active,
        assignedByUserId: 'm',
      );

      expect(base.toMap().containsKey('userPhotoUrl'), isFalse);
      expect(base.hasPhoto, isFalse);

      final withPhoto = TeamAssignment.fromMap('a', {
        ...base.toMap(),
        'userPhotoUrl': _photo,
      });

      expect(withPhoto.hasPhoto, isTrue);
      expect(withPhoto.toMap()['userPhotoUrl'], _photo);
    });

    test('alineaciones anteriores sin fotos se leen sin error', () {
      final lineup = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['a', 'b', '', '', ''],
        'playerNames': ['A', 'B', '', '', ''],
      });

      expect(lineup.photoAt(0), '');

      final withPhotos = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['a', 'b', '', '', ''],
        'playerNames': ['A', 'B', '', '', ''],
        'playerPhotoUrls': [_photo, '', '', '', ''],
      });

      expect(withPhotos.photoAt(0), _photo);
      expect(withPhotos.photoAt(9), '');
    });
  });

  testWidgets('el avatar sin foto muestra la inicial', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerAvatar(name: 'Diego', photoUrl: ''),
        ),
      ),
    );

    expect(find.text('D'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('la pantalla de la foto cabe en 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: FacePhotoCaptureScreen()));

    expect(find.text('Tómate una foto de la cara'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    // Sin foto válida no se puede confirmar.
    expect(find.text('Usar esta foto'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
