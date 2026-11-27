// This is a generated file - do not edit.
//
// Generated from engine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'engine.pbenum.dart';

enum ToEngine_Kind {
  setCard,
  setSetup,
  audition,
  note,
  setDevices,
  shutdown,
  renderPiece,
  cancelRender,
  play,
  seek,
  stop,
  playPiece,
  stopPiece,
  notSet
}

class ToEngine extends $pb.GeneratedMessage {
  factory ToEngine({
    SetCard? setCard,
    SetSetup? setSetup,
    Audition? audition,
    Note? note,
    SetDevices? setDevices,
    Shutdown? shutdown,
    RenderPiece? renderPiece,
    CancelRender? cancelRender,
    Play? play,
    Seek? seek,
    Stop? stop,
    PlayPiece? playPiece,
    StopPiece? stopPiece,
  }) {
    final result = ToEngine._();
    if (setCard != null) result.setCard = setCard;
    if (setSetup != null) result.setSetup = setSetup;
    if (audition != null) result.audition = audition;
    if (note != null) result.note = note;
    if (setDevices != null) result.setDevices = setDevices;
    if (shutdown != null) result.shutdown = shutdown;
    if (renderPiece != null) result.renderPiece = renderPiece;
    if (cancelRender != null) result.cancelRender = cancelRender;
    if (play != null) result.play = play;
    if (seek != null) result.seek = seek;
    if (stop != null) result.stop = stop;
    if (playPiece != null) result.playPiece = playPiece;
    if (stopPiece != null) result.stopPiece = stopPiece;
    return result;
  }

  ToEngine._();

  factory ToEngine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToEngine()..mergeFromBuffer(data, registry);
  factory ToEngine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ToEngine()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ToEngine_Kind> _ToEngine_KindByTag = {
    1: ToEngine_Kind.setCard,
    2: ToEngine_Kind.setSetup,
    3: ToEngine_Kind.audition,
    4: ToEngine_Kind.note,
    5: ToEngine_Kind.setDevices,
    6: ToEngine_Kind.shutdown,
    7: ToEngine_Kind.renderPiece,
    8: ToEngine_Kind.cancelRender,
    9: ToEngine_Kind.play,
    10: ToEngine_Kind.seek,
    11: ToEngine_Kind.stop,
    12: ToEngine_Kind.playPiece,
    13: ToEngine_Kind.stopPiece,
    0: ToEngine_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToEngine',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: ToEngine.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    ..aOM<SetCard>(1, _omitFieldNames ? '' : 'setCard',
        subBuilder: SetCard.$_createMessage)
    ..aOM<SetSetup>(2, _omitFieldNames ? '' : 'setSetup',
        subBuilder: SetSetup.$_createMessage)
    ..aOM<Audition>(3, _omitFieldNames ? '' : 'audition',
        subBuilder: Audition.$_createMessage)
    ..aOM<Note>(4, _omitFieldNames ? '' : 'note',
        subBuilder: Note.$_createMessage)
    ..aOM<SetDevices>(5, _omitFieldNames ? '' : 'setDevices',
        subBuilder: SetDevices.$_createMessage)
    ..aOM<Shutdown>(6, _omitFieldNames ? '' : 'shutdown',
        subBuilder: Shutdown.$_createMessage)
    ..aOM<RenderPiece>(7, _omitFieldNames ? '' : 'renderPiece',
        subBuilder: RenderPiece.$_createMessage)
    ..aOM<CancelRender>(8, _omitFieldNames ? '' : 'cancelRender',
        subBuilder: CancelRender.$_createMessage)
    ..aOM<Play>(9, _omitFieldNames ? '' : 'play',
        subBuilder: Play.$_createMessage)
    ..aOM<Seek>(10, _omitFieldNames ? '' : 'seek',
        subBuilder: Seek.$_createMessage)
    ..aOM<Stop>(11, _omitFieldNames ? '' : 'stop',
        subBuilder: Stop.$_createMessage)
    ..aOM<PlayPiece>(12, _omitFieldNames ? '' : 'playPiece',
        subBuilder: PlayPiece.$_createMessage)
    ..aOM<StopPiece>(13, _omitFieldNames ? '' : 'stopPiece',
        subBuilder: StopPiece.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToEngine clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToEngine copyWith(void Function(ToEngine) updates) =>
      super.copyWith((message) => updates(message as ToEngine)) as ToEngine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ToEngine() / ToEngine.new instead')
  static ToEngine create() => ToEngine._();
  static $pb.GeneratedMessage $_createMessage() => ToEngine._();
  @$core.override
  ToEngine createEmptyInstance() => ToEngine._();
  @$core.pragma('dart2js:noInline')
  static ToEngine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ToEngine>(ToEngine.$_createMessage);
  static ToEngine? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  ToEngine_Kind whichKind() => _ToEngine_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  void clearKind() => $_clearField($_whichOneof(0));

  /// Card, Setup, devices, lifecycle (spec §7.4)
  @$pb.TagNumber(1)
  SetCard get setCard => $_getN(0);
  @$pb.TagNumber(1)
  set setCard(SetCard value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSetCard() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetCard() => $_clearField(1);
  @$pb.TagNumber(1)
  SetCard ensureSetCard() => $_ensure(0);

  @$pb.TagNumber(2)
  SetSetup get setSetup => $_getN(1);
  @$pb.TagNumber(2)
  set setSetup(SetSetup value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSetSetup() => $_has(1);
  @$pb.TagNumber(2)
  void clearSetSetup() => $_clearField(2);
  @$pb.TagNumber(2)
  SetSetup ensureSetSetup() => $_ensure(1);

  @$pb.TagNumber(3)
  Audition get audition => $_getN(2);
  @$pb.TagNumber(3)
  set audition(Audition value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAudition() => $_has(2);
  @$pb.TagNumber(3)
  void clearAudition() => $_clearField(3);
  @$pb.TagNumber(3)
  Audition ensureAudition() => $_ensure(2);

  @$pb.TagNumber(4)
  Note get note => $_getN(3);
  @$pb.TagNumber(4)
  set note(Note value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearNote() => $_clearField(4);
  @$pb.TagNumber(4)
  Note ensureNote() => $_ensure(3);

  @$pb.TagNumber(5)
  SetDevices get setDevices => $_getN(4);
  @$pb.TagNumber(5)
  set setDevices(SetDevices value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSetDevices() => $_has(4);
  @$pb.TagNumber(5)
  void clearSetDevices() => $_clearField(5);
  @$pb.TagNumber(5)
  SetDevices ensureSetDevices() => $_ensure(4);

  @$pb.TagNumber(6)
  Shutdown get shutdown => $_getN(5);
  @$pb.TagNumber(6)
  set shutdown(Shutdown value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasShutdown() => $_has(5);
  @$pb.TagNumber(6)
  void clearShutdown() => $_clearField(6);
  @$pb.TagNumber(6)
  Shutdown ensureShutdown() => $_ensure(5);

  /// Pieces and Renders (spec §7.5)
  @$pb.TagNumber(7)
  RenderPiece get renderPiece => $_getN(6);
  @$pb.TagNumber(7)
  set renderPiece(RenderPiece value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRenderPiece() => $_has(6);
  @$pb.TagNumber(7)
  void clearRenderPiece() => $_clearField(7);
  @$pb.TagNumber(7)
  RenderPiece ensureRenderPiece() => $_ensure(6);

  @$pb.TagNumber(8)
  CancelRender get cancelRender => $_getN(7);
  @$pb.TagNumber(8)
  set cancelRender(CancelRender value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCancelRender() => $_has(7);
  @$pb.TagNumber(8)
  void clearCancelRender() => $_clearField(8);
  @$pb.TagNumber(8)
  CancelRender ensureCancelRender() => $_ensure(7);

  @$pb.TagNumber(9)
  Play get play => $_getN(8);
  @$pb.TagNumber(9)
  set play(Play value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPlay() => $_has(8);
  @$pb.TagNumber(9)
  void clearPlay() => $_clearField(9);
  @$pb.TagNumber(9)
  Play ensurePlay() => $_ensure(8);

  @$pb.TagNumber(10)
  Seek get seek => $_getN(9);
  @$pb.TagNumber(10)
  set seek(Seek value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSeek() => $_has(9);
  @$pb.TagNumber(10)
  void clearSeek() => $_clearField(10);
  @$pb.TagNumber(10)
  Seek ensureSeek() => $_ensure(9);

  @$pb.TagNumber(11)
  Stop get stop => $_getN(10);
  @$pb.TagNumber(11)
  set stop(Stop value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasStop() => $_has(10);
  @$pb.TagNumber(11)
  void clearStop() => $_clearField(11);
  @$pb.TagNumber(11)
  Stop ensureStop() => $_ensure(10);

  @$pb.TagNumber(12)
  PlayPiece get playPiece => $_getN(11);
  @$pb.TagNumber(12)
  set playPiece(PlayPiece value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasPlayPiece() => $_has(11);
  @$pb.TagNumber(12)
  void clearPlayPiece() => $_clearField(12);
  @$pb.TagNumber(12)
  PlayPiece ensurePlayPiece() => $_ensure(11);

  @$pb.TagNumber(13)
  StopPiece get stopPiece => $_getN(12);
  @$pb.TagNumber(13)
  set stopPiece(StopPiece value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasStopPiece() => $_has(12);
  @$pb.TagNumber(13)
  void clearStopPiece() => $_clearField(13);
  @$pb.TagNumber(13)
  StopPiece ensureStopPiece() => $_ensure(12);
}

enum FromEngine_Kind {
  hello,
  heartbeat,
  cardStatus,
  catalog,
  genres,
  setupApplied,
  midiActivity,
  devices,
  freeze_9,
  renderProgress,
  renderDone,
  renderFailed,
  position,
  error,
  notSet
}

class FromEngine extends $pb.GeneratedMessage {
  factory FromEngine({
    Hello? hello,
    Heartbeat? heartbeat,
    CardStatus? cardStatus,
    Catalog? catalog,
    Genres? genres,
    SetupApplied? setupApplied,
    MidiActivity? midiActivity,
    Devices? devices,
    Freeze? freeze_9,
    RenderProgress? renderProgress,
    RenderDone? renderDone,
    RenderFailed? renderFailed,
    Position? position,
    ErrorReply? error,
  }) {
    final result = FromEngine._();
    if (hello != null) result.hello = hello;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (cardStatus != null) result.cardStatus = cardStatus;
    if (catalog != null) result.catalog = catalog;
    if (genres != null) result.genres = genres;
    if (setupApplied != null) result.setupApplied = setupApplied;
    if (midiActivity != null) result.midiActivity = midiActivity;
    if (devices != null) result.devices = devices;
    if (freeze_9 != null) result.freeze_9 = freeze_9;
    if (renderProgress != null) result.renderProgress = renderProgress;
    if (renderDone != null) result.renderDone = renderDone;
    if (renderFailed != null) result.renderFailed = renderFailed;
    if (position != null) result.position = position;
    if (error != null) result.error = error;
    return result;
  }

  FromEngine._();

  factory FromEngine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FromEngine()..mergeFromBuffer(data, registry);
  factory FromEngine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FromEngine()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, FromEngine_Kind> _FromEngine_KindByTag = {
    1: FromEngine_Kind.hello,
    2: FromEngine_Kind.heartbeat,
    3: FromEngine_Kind.cardStatus,
    4: FromEngine_Kind.catalog,
    5: FromEngine_Kind.genres,
    6: FromEngine_Kind.setupApplied,
    7: FromEngine_Kind.midiActivity,
    8: FromEngine_Kind.devices,
    9: FromEngine_Kind.freeze_9,
    10: FromEngine_Kind.renderProgress,
    11: FromEngine_Kind.renderDone,
    12: FromEngine_Kind.renderFailed,
    13: FromEngine_Kind.position,
    14: FromEngine_Kind.error,
    0: FromEngine_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FromEngine',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: FromEngine.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14])
    ..aOM<Hello>(1, _omitFieldNames ? '' : 'hello',
        subBuilder: Hello.$_createMessage)
    ..aOM<Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.$_createMessage)
    ..aOM<CardStatus>(3, _omitFieldNames ? '' : 'cardStatus',
        subBuilder: CardStatus.$_createMessage)
    ..aOM<Catalog>(4, _omitFieldNames ? '' : 'catalog',
        subBuilder: Catalog.$_createMessage)
    ..aOM<Genres>(5, _omitFieldNames ? '' : 'genres',
        subBuilder: Genres.$_createMessage)
    ..aOM<SetupApplied>(6, _omitFieldNames ? '' : 'setupApplied',
        subBuilder: SetupApplied.$_createMessage)
    ..aOM<MidiActivity>(7, _omitFieldNames ? '' : 'midiActivity',
        subBuilder: MidiActivity.$_createMessage)
    ..aOM<Devices>(8, _omitFieldNames ? '' : 'devices',
        subBuilder: Devices.$_createMessage)
    ..aOM<Freeze>(9, _omitFieldNames ? '' : 'freeze',
        subBuilder: Freeze.$_createMessage)
    ..aOM<RenderProgress>(10, _omitFieldNames ? '' : 'renderProgress',
        subBuilder: RenderProgress.$_createMessage)
    ..aOM<RenderDone>(11, _omitFieldNames ? '' : 'renderDone',
        subBuilder: RenderDone.$_createMessage)
    ..aOM<RenderFailed>(12, _omitFieldNames ? '' : 'renderFailed',
        subBuilder: RenderFailed.$_createMessage)
    ..aOM<Position>(13, _omitFieldNames ? '' : 'position',
        subBuilder: Position.$_createMessage)
    ..aOM<ErrorReply>(14, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorReply.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FromEngine clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FromEngine copyWith(void Function(FromEngine) updates) =>
      super.copyWith((message) => updates(message as FromEngine)) as FromEngine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FromEngine() / FromEngine.new instead')
  static FromEngine create() => FromEngine._();
  static $pb.GeneratedMessage $_createMessage() => FromEngine._();
  @$core.override
  FromEngine createEmptyInstance() => FromEngine._();
  @$core.pragma('dart2js:noInline')
  static FromEngine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FromEngine>(FromEngine.$_createMessage);
  static FromEngine? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  FromEngine_Kind whichKind() => _FromEngine_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  void clearKind() => $_clearField($_whichOneof(0));

  /// Session, card, Setup, devices, status (spec §7.2, §7.4, §7.7)
  @$pb.TagNumber(1)
  Hello get hello => $_getN(0);
  @$pb.TagNumber(1)
  set hello(Hello value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHello() => $_has(0);
  @$pb.TagNumber(1)
  void clearHello() => $_clearField(1);
  @$pb.TagNumber(1)
  Hello ensureHello() => $_ensure(0);

  @$pb.TagNumber(2)
  Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat(Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  Heartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  CardStatus get cardStatus => $_getN(2);
  @$pb.TagNumber(3)
  set cardStatus(CardStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCardStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearCardStatus() => $_clearField(3);
  @$pb.TagNumber(3)
  CardStatus ensureCardStatus() => $_ensure(2);

  @$pb.TagNumber(4)
  Catalog get catalog => $_getN(3);
  @$pb.TagNumber(4)
  set catalog(Catalog value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCatalog() => $_has(3);
  @$pb.TagNumber(4)
  void clearCatalog() => $_clearField(4);
  @$pb.TagNumber(4)
  Catalog ensureCatalog() => $_ensure(3);

  @$pb.TagNumber(5)
  Genres get genres => $_getN(4);
  @$pb.TagNumber(5)
  set genres(Genres value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasGenres() => $_has(4);
  @$pb.TagNumber(5)
  void clearGenres() => $_clearField(5);
  @$pb.TagNumber(5)
  Genres ensureGenres() => $_ensure(4);

  @$pb.TagNumber(6)
  SetupApplied get setupApplied => $_getN(5);
  @$pb.TagNumber(6)
  set setupApplied(SetupApplied value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSetupApplied() => $_has(5);
  @$pb.TagNumber(6)
  void clearSetupApplied() => $_clearField(6);
  @$pb.TagNumber(6)
  SetupApplied ensureSetupApplied() => $_ensure(5);

  @$pb.TagNumber(7)
  MidiActivity get midiActivity => $_getN(6);
  @$pb.TagNumber(7)
  set midiActivity(MidiActivity value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMidiActivity() => $_has(6);
  @$pb.TagNumber(7)
  void clearMidiActivity() => $_clearField(7);
  @$pb.TagNumber(7)
  MidiActivity ensureMidiActivity() => $_ensure(6);

  @$pb.TagNumber(8)
  Devices get devices => $_getN(7);
  @$pb.TagNumber(8)
  set devices(Devices value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDevices() => $_has(7);
  @$pb.TagNumber(8)
  void clearDevices() => $_clearField(8);
  @$pb.TagNumber(8)
  Devices ensureDevices() => $_ensure(7);

  @$pb.TagNumber(9)
  Freeze get freeze_9 => $_getN(8);
  @$pb.TagNumber(9)
  set freeze_9(Freeze value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFreeze_9() => $_has(8);
  @$pb.TagNumber(9)
  void clearFreeze_9() => $_clearField(9);
  @$pb.TagNumber(9)
  Freeze ensureFreeze_9() => $_ensure(8);

  /// Pieces and Renders (spec §7.5)
  @$pb.TagNumber(10)
  RenderProgress get renderProgress => $_getN(9);
  @$pb.TagNumber(10)
  set renderProgress(RenderProgress value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRenderProgress() => $_has(9);
  @$pb.TagNumber(10)
  void clearRenderProgress() => $_clearField(10);
  @$pb.TagNumber(10)
  RenderProgress ensureRenderProgress() => $_ensure(9);

  @$pb.TagNumber(11)
  RenderDone get renderDone => $_getN(10);
  @$pb.TagNumber(11)
  set renderDone(RenderDone value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRenderDone() => $_has(10);
  @$pb.TagNumber(11)
  void clearRenderDone() => $_clearField(11);
  @$pb.TagNumber(11)
  RenderDone ensureRenderDone() => $_ensure(10);

  @$pb.TagNumber(12)
  RenderFailed get renderFailed => $_getN(11);
  @$pb.TagNumber(12)
  set renderFailed(RenderFailed value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasRenderFailed() => $_has(11);
  @$pb.TagNumber(12)
  void clearRenderFailed() => $_clearField(12);
  @$pb.TagNumber(12)
  RenderFailed ensureRenderFailed() => $_ensure(11);

  @$pb.TagNumber(13)
  Position get position => $_getN(12);
  @$pb.TagNumber(13)
  set position(Position value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasPosition() => $_has(12);
  @$pb.TagNumber(13)
  void clearPosition() => $_clearField(13);
  @$pb.TagNumber(13)
  Position ensurePosition() => $_ensure(12);

  /// Generic command/playback error reply (unimplemented command, audition full, missing WAV)
  @$pb.TagNumber(14)
  ErrorReply get error => $_getN(13);
  @$pb.TagNumber(14)
  set error(ErrorReply value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasError() => $_has(13);
  @$pb.TagNumber(14)
  void clearError() => $_clearField(14);
  @$pb.TagNumber(14)
  ErrorReply ensureError() => $_ensure(13);
}

class SetCard extends $pb.GeneratedMessage {
  factory SetCard({
    $core.String? folder,
  }) {
    final result = SetCard._();
    if (folder != null) result.folder = folder;
    return result;
  }

  SetCard._();

  factory SetCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetCard()..mergeFromBuffer(data, registry);
  factory SetCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetCard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetCard',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SetCard.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetCard copyWith(void Function(SetCard) updates) =>
      super.copyWith((message) => updates(message as SetCard)) as SetCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetCard() / SetCard.new instead')
  static SetCard create() => SetCard._();
  static $pb.GeneratedMessage $_createMessage() => SetCard._();
  @$core.override
  SetCard createEmptyInstance() => SetCard._();
  @$core.pragma('dart2js:noInline')
  static SetCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetCard>(SetCard.$_createMessage);
  static SetCard? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);
}

class SetupBinding extends $pb.GeneratedMessage {
  factory SetupBinding({
    $core.int? channel,
    $core.String? path,
  }) {
    final result = SetupBinding._();
    if (channel != null) result.channel = channel;
    if (path != null) result.path = path;
    return result;
  }

  SetupBinding._();

  factory SetupBinding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetupBinding()..mergeFromBuffer(data, registry);
  factory SetupBinding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetupBinding()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetupBinding',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SetupBinding.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetupBinding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetupBinding copyWith(void Function(SetupBinding) updates) =>
      super.copyWith((message) => updates(message as SetupBinding))
          as SetupBinding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetupBinding() / SetupBinding.new instead')
  static SetupBinding create() => SetupBinding._();
  static $pb.GeneratedMessage $_createMessage() => SetupBinding._();
  @$core.override
  SetupBinding createEmptyInstance() => SetupBinding._();
  @$core.pragma('dart2js:noInline')
  static SetupBinding getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetupBinding>(
          SetupBinding.$_createMessage);
  static SetupBinding? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get channel => $_getIZ(0);
  @$pb.TagNumber(1)
  set channel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);
}

class SetSetup extends $pb.GeneratedMessage {
  factory SetSetup({
    $core.Iterable<SetupBinding>? bindings,
  }) {
    final result = SetSetup._();
    if (bindings != null) result.bindings.addAll(bindings);
    return result;
  }

  SetSetup._();

  factory SetSetup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSetup()..mergeFromBuffer(data, registry);
  factory SetSetup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSetup()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSetup',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SetSetup.$_createMessage)
    ..pPM<SetupBinding>(1, _omitFieldNames ? '' : 'bindings',
        subBuilder: SetupBinding.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSetup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSetup copyWith(void Function(SetSetup) updates) =>
      super.copyWith((message) => updates(message as SetSetup)) as SetSetup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetSetup() / SetSetup.new instead')
  static SetSetup create() => SetSetup._();
  static $pb.GeneratedMessage $_createMessage() => SetSetup._();
  @$core.override
  SetSetup createEmptyInstance() => SetSetup._();
  @$core.pragma('dart2js:noInline')
  static SetSetup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetSetup>(SetSetup.$_createMessage);
  static SetSetup? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SetupBinding> get bindings => $_getList(0);
}

class Audition extends $pb.GeneratedMessage {
  factory Audition({
    $core.String? path,
    $core.int? note,
    $core.int? velocity,
    $core.int? ms,
  }) {
    final result = Audition._();
    if (path != null) result.path = path;
    if (note != null) result.note = note;
    if (velocity != null) result.velocity = velocity;
    if (ms != null) result.ms = ms;
    return result;
  }

  Audition._();

  factory Audition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Audition()..mergeFromBuffer(data, registry);
  factory Audition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Audition()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Audition',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Audition.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aI(2, _omitFieldNames ? '' : 'note', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'velocity', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'ms', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Audition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Audition copyWith(void Function(Audition) updates) =>
      super.copyWith((message) => updates(message as Audition)) as Audition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Audition() / Audition.new instead')
  static Audition create() => Audition._();
  static $pb.GeneratedMessage $_createMessage() => Audition._();
  @$core.override
  Audition createEmptyInstance() => Audition._();
  @$core.pragma('dart2js:noInline')
  static Audition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Audition>(Audition.$_createMessage);
  static Audition? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get note => $_getIZ(1);
  @$pb.TagNumber(2)
  set note($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNote() => $_has(1);
  @$pb.TagNumber(2)
  void clearNote() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get velocity => $_getIZ(2);
  @$pb.TagNumber(3)
  set velocity($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVelocity() => $_has(2);
  @$pb.TagNumber(3)
  void clearVelocity() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get ms => $_getIZ(3);
  @$pb.TagNumber(4)
  set ms($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearMs() => $_clearField(4);
}

class Note extends $pb.GeneratedMessage {
  factory Note({
    $core.int? channel,
    $core.int? note,
    $core.int? velocity,
    $core.bool? on,
  }) {
    final result = Note._();
    if (channel != null) result.channel = channel;
    if (note != null) result.note = note;
    if (velocity != null) result.velocity = velocity;
    if (on != null) result.on = on;
    return result;
  }

  Note._();

  factory Note.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Note()..mergeFromBuffer(data, registry);
  factory Note.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Note()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Note',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Note.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'note', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'velocity', fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'on')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Note clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Note copyWith(void Function(Note) updates) =>
      super.copyWith((message) => updates(message as Note)) as Note;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Note() / Note.new instead')
  static Note create() => Note._();
  static $pb.GeneratedMessage $_createMessage() => Note._();
  @$core.override
  Note createEmptyInstance() => Note._();
  @$core.pragma('dart2js:noInline')
  static Note getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Note>(Note.$_createMessage);
  static Note? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get channel => $_getIZ(0);
  @$pb.TagNumber(1)
  set channel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get note => $_getIZ(1);
  @$pb.TagNumber(2)
  set note($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNote() => $_has(1);
  @$pb.TagNumber(2)
  void clearNote() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get velocity => $_getIZ(2);
  @$pb.TagNumber(3)
  set velocity($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVelocity() => $_has(2);
  @$pb.TagNumber(3)
  void clearVelocity() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get on => $_getBF(3);
  @$pb.TagNumber(4)
  set on($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOn() => $_has(3);
  @$pb.TagNumber(4)
  void clearOn() => $_clearField(4);
}

class SetDevices extends $pb.GeneratedMessage {
  factory SetDevices({
    $core.String? audioOutput,
    $core.Iterable<$core.String>? midiInputs,
  }) {
    final result = SetDevices._();
    if (audioOutput != null) result.audioOutput = audioOutput;
    if (midiInputs != null) result.midiInputs.addAll(midiInputs);
    return result;
  }

  SetDevices._();

  factory SetDevices.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDevices()..mergeFromBuffer(data, registry);
  factory SetDevices.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDevices()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetDevices',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SetDevices.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'audioOutput')
    ..pPS(2, _omitFieldNames ? '' : 'midiInputs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDevices clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDevices copyWith(void Function(SetDevices) updates) =>
      super.copyWith((message) => updates(message as SetDevices)) as SetDevices;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetDevices() / SetDevices.new instead')
  static SetDevices create() => SetDevices._();
  static $pb.GeneratedMessage $_createMessage() => SetDevices._();
  @$core.override
  SetDevices createEmptyInstance() => SetDevices._();
  @$core.pragma('dart2js:noInline')
  static SetDevices getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetDevices>(SetDevices.$_createMessage);
  static SetDevices? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get audioOutput => $_getSZ(0);
  @$pb.TagNumber(1)
  set audioOutput($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudioOutput() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudioOutput() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get midiInputs => $_getList(1);
}

class Shutdown extends $pb.GeneratedMessage {
  factory Shutdown() => Shutdown._();

  Shutdown._();

  factory Shutdown.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shutdown()..mergeFromBuffer(data, registry);
  factory Shutdown.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shutdown()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Shutdown',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Shutdown.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shutdown clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shutdown copyWith(void Function(Shutdown) updates) =>
      super.copyWith((message) => updates(message as Shutdown)) as Shutdown;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Shutdown() / Shutdown.new instead')
  static Shutdown create() => Shutdown._();
  static $pb.GeneratedMessage $_createMessage() => Shutdown._();
  @$core.override
  Shutdown createEmptyInstance() => Shutdown._();
  @$core.pragma('dart2js:noInline')
  static Shutdown getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Shutdown>(Shutdown.$_createMessage);
  static Shutdown? _defaultInstance;
}

enum SoundPick_Target { part, lane, notSet }

class SoundPick extends $pb.GeneratedMessage {
  factory SoundPick({
    $core.int? part,
    $core.int? lane,
    $core.String? path,
  }) {
    final result = SoundPick._();
    if (part != null) result.part = part;
    if (lane != null) result.lane = lane;
    if (path != null) result.path = path;
    return result;
  }

  SoundPick._();

  factory SoundPick.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SoundPick()..mergeFromBuffer(data, registry);
  factory SoundPick.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SoundPick()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SoundPick_Target> _SoundPick_TargetByTag = {
    1: SoundPick_Target.part,
    2: SoundPick_Target.lane,
    0: SoundPick_Target.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SoundPick',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SoundPick.$_createMessage)
    ..oo(0, [1, 2])
    ..aI(1, _omitFieldNames ? '' : 'part', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'lane', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SoundPick clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SoundPick copyWith(void Function(SoundPick) updates) =>
      super.copyWith((message) => updates(message as SoundPick)) as SoundPick;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SoundPick() / SoundPick.new instead')
  static SoundPick create() => SoundPick._();
  static $pb.GeneratedMessage $_createMessage() => SoundPick._();
  @$core.override
  SoundPick createEmptyInstance() => SoundPick._();
  @$core.pragma('dart2js:noInline')
  static SoundPick getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SoundPick>(SoundPick.$_createMessage);
  static SoundPick? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  SoundPick_Target whichTarget() => _SoundPick_TargetByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTarget() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get part => $_getIZ(0);
  @$pb.TagNumber(1)
  set part($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPart() => $_has(0);
  @$pb.TagNumber(1)
  void clearPart() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get lane => $_getIZ(1);
  @$pb.TagNumber(2)
  set lane($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLane() => $_has(1);
  @$pb.TagNumber(2)
  void clearLane() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get path => $_getSZ(2);
  @$pb.TagNumber(3)
  set path($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearPath() => $_clearField(3);
}

class Recipe extends $pb.GeneratedMessage {
  factory Recipe({
    $core.String? genre,
    $core.int? seed,
    $core.int? entropy,
    $core.Iterable<$core.int>? macros,
    $core.double? tempo,
    $core.int? key,
    $core.int? scale,
    $core.int? swing,
    $core.Iterable<SoundPick>? picks,
    $core.String? scaleName,
  }) {
    final result = Recipe._();
    if (genre != null) result.genre = genre;
    if (seed != null) result.seed = seed;
    if (entropy != null) result.entropy = entropy;
    if (macros != null) result.macros.addAll(macros);
    if (tempo != null) result.tempo = tempo;
    if (key != null) result.key = key;
    if (scale != null) result.scale = scale;
    if (swing != null) result.swing = swing;
    if (picks != null) result.picks.addAll(picks);
    if (scaleName != null) result.scaleName = scaleName;
    return result;
  }

  Recipe._();

  factory Recipe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Recipe()..mergeFromBuffer(data, registry);
  factory Recipe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Recipe()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Recipe',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Recipe.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'genre')
    ..aI(2, _omitFieldNames ? '' : 'seed', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'entropy', fieldType: $pb.PbFieldType.OU3)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'macros', $pb.PbFieldType.K3)
    ..aD(5, _omitFieldNames ? '' : 'tempo')
    ..aI(6, _omitFieldNames ? '' : 'key', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'scale', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'swing')
    ..pPM<SoundPick>(9, _omitFieldNames ? '' : 'picks',
        subBuilder: SoundPick.$_createMessage)
    ..aOS(10, _omitFieldNames ? '' : 'scaleName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Recipe clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Recipe copyWith(void Function(Recipe) updates) =>
      super.copyWith((message) => updates(message as Recipe)) as Recipe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Recipe() / Recipe.new instead')
  static Recipe create() => Recipe._();
  static $pb.GeneratedMessage $_createMessage() => Recipe._();
  @$core.override
  Recipe createEmptyInstance() => Recipe._();
  @$core.pragma('dart2js:noInline')
  static Recipe getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Recipe>(Recipe.$_createMessage);
  static Recipe? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get genre => $_getSZ(0);
  @$pb.TagNumber(1)
  set genre($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGenre() => $_has(0);
  @$pb.TagNumber(1)
  void clearGenre() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get seed => $_getIZ(1);
  @$pb.TagNumber(2)
  set seed($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeed() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeed() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get entropy => $_getIZ(2);
  @$pb.TagNumber(3)
  set entropy($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEntropy() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntropy() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get macros => $_getList(3);

  @$pb.TagNumber(5)
  $core.double get tempo => $_getN(4);
  @$pb.TagNumber(5)
  set tempo($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTempo() => $_has(4);
  @$pb.TagNumber(5)
  void clearTempo() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get key => $_getIZ(5);
  @$pb.TagNumber(6)
  set key($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearKey() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get scale => $_getIZ(6);
  @$pb.TagNumber(7)
  set scale($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasScale() => $_has(6);
  @$pb.TagNumber(7)
  void clearScale() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get swing => $_getIZ(7);
  @$pb.TagNumber(8)
  set swing($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSwing() => $_has(7);
  @$pb.TagNumber(8)
  void clearSwing() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<SoundPick> get picks => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get scaleName => $_getSZ(9);
  @$pb.TagNumber(10)
  set scaleName($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasScaleName() => $_has(9);
  @$pb.TagNumber(10)
  void clearScaleName() => $_clearField(10);
}

class RenderPiece extends $pb.GeneratedMessage {
  factory RenderPiece({
    $core.String? id,
    Recipe? recipe,
    $core.double? lengthS,
    $core.String? wavPath,
  }) {
    final result = RenderPiece._();
    if (id != null) result.id = id;
    if (recipe != null) result.recipe = recipe;
    if (lengthS != null) result.lengthS = lengthS;
    if (wavPath != null) result.wavPath = wavPath;
    return result;
  }

  RenderPiece._();

  factory RenderPiece.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderPiece()..mergeFromBuffer(data, registry);
  factory RenderPiece.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderPiece()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderPiece',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: RenderPiece.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<Recipe>(2, _omitFieldNames ? '' : 'recipe',
        subBuilder: Recipe.$_createMessage)
    ..aD(3, _omitFieldNames ? '' : 'lengthS')
    ..aOS(4, _omitFieldNames ? '' : 'wavPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderPiece clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderPiece copyWith(void Function(RenderPiece) updates) =>
      super.copyWith((message) => updates(message as RenderPiece))
          as RenderPiece;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenderPiece() / RenderPiece.new instead')
  static RenderPiece create() => RenderPiece._();
  static $pb.GeneratedMessage $_createMessage() => RenderPiece._();
  @$core.override
  RenderPiece createEmptyInstance() => RenderPiece._();
  @$core.pragma('dart2js:noInline')
  static RenderPiece getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenderPiece>(
          RenderPiece.$_createMessage);
  static RenderPiece? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  Recipe get recipe => $_getN(1);
  @$pb.TagNumber(2)
  set recipe(Recipe value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRecipe() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecipe() => $_clearField(2);
  @$pb.TagNumber(2)
  Recipe ensureRecipe() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.double get lengthS => $_getN(2);
  @$pb.TagNumber(3)
  set lengthS($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLengthS() => $_has(2);
  @$pb.TagNumber(3)
  void clearLengthS() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get wavPath => $_getSZ(3);
  @$pb.TagNumber(4)
  set wavPath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWavPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearWavPath() => $_clearField(4);
}

class CancelRender extends $pb.GeneratedMessage {
  factory CancelRender({
    $core.String? id,
  }) {
    final result = CancelRender._();
    if (id != null) result.id = id;
    return result;
  }

  CancelRender._();

  factory CancelRender.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelRender()..mergeFromBuffer(data, registry);
  factory CancelRender.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelRender()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelRender',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: CancelRender.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelRender clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelRender copyWith(void Function(CancelRender) updates) =>
      super.copyWith((message) => updates(message as CancelRender))
          as CancelRender;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CancelRender() / CancelRender.new instead')
  static CancelRender create() => CancelRender._();
  static $pb.GeneratedMessage $_createMessage() => CancelRender._();
  @$core.override
  CancelRender createEmptyInstance() => CancelRender._();
  @$core.pragma('dart2js:noInline')
  static CancelRender getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CancelRender>(
          CancelRender.$_createMessage);
  static CancelRender? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class Play extends $pb.GeneratedMessage {
  factory Play({
    $core.String? wavPath,
    $core.double? positionS,
  }) {
    final result = Play._();
    if (wavPath != null) result.wavPath = wavPath;
    if (positionS != null) result.positionS = positionS;
    return result;
  }

  Play._();

  factory Play.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Play()..mergeFromBuffer(data, registry);
  factory Play.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Play()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Play',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Play.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'wavPath')
    ..aD(2, _omitFieldNames ? '' : 'positionS')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Play clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Play copyWith(void Function(Play) updates) =>
      super.copyWith((message) => updates(message as Play)) as Play;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Play() / Play.new instead')
  static Play create() => Play._();
  static $pb.GeneratedMessage $_createMessage() => Play._();
  @$core.override
  Play createEmptyInstance() => Play._();
  @$core.pragma('dart2js:noInline')
  static Play getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Play>(Play.$_createMessage);
  static Play? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get wavPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set wavPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWavPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWavPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get positionS => $_getN(1);
  @$pb.TagNumber(2)
  set positionS($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPositionS() => $_has(1);
  @$pb.TagNumber(2)
  void clearPositionS() => $_clearField(2);
}

class Seek extends $pb.GeneratedMessage {
  factory Seek({
    $core.double? positionS,
  }) {
    final result = Seek._();
    if (positionS != null) result.positionS = positionS;
    return result;
  }

  Seek._();

  factory Seek.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Seek()..mergeFromBuffer(data, registry);
  factory Seek.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Seek()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Seek',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Seek.$_createMessage)
    ..aD(1, _omitFieldNames ? '' : 'positionS')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Seek clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Seek copyWith(void Function(Seek) updates) =>
      super.copyWith((message) => updates(message as Seek)) as Seek;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Seek() / Seek.new instead')
  static Seek create() => Seek._();
  static $pb.GeneratedMessage $_createMessage() => Seek._();
  @$core.override
  Seek createEmptyInstance() => Seek._();
  @$core.pragma('dart2js:noInline')
  static Seek getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Seek>(Seek.$_createMessage);
  static Seek? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get positionS => $_getN(0);
  @$pb.TagNumber(1)
  set positionS($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPositionS() => $_has(0);
  @$pb.TagNumber(1)
  void clearPositionS() => $_clearField(1);
}

class Stop extends $pb.GeneratedMessage {
  factory Stop() => Stop._();

  Stop._();

  factory Stop.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Stop()..mergeFromBuffer(data, registry);
  factory Stop.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Stop()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Stop',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Stop.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Stop clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Stop copyWith(void Function(Stop) updates) =>
      super.copyWith((message) => updates(message as Stop)) as Stop;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Stop() / Stop.new instead')
  static Stop create() => Stop._();
  static $pb.GeneratedMessage $_createMessage() => Stop._();
  @$core.override
  Stop createEmptyInstance() => Stop._();
  @$core.pragma('dart2js:noInline')
  static Stop getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Stop>(Stop.$_createMessage);
  static Stop? _defaultInstance;
}

class PlayPiece extends $pb.GeneratedMessage {
  factory PlayPiece({
    Recipe? recipe,
  }) {
    final result = PlayPiece._();
    if (recipe != null) result.recipe = recipe;
    return result;
  }

  PlayPiece._();

  factory PlayPiece.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayPiece()..mergeFromBuffer(data, registry);
  factory PlayPiece.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayPiece()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayPiece',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: PlayPiece.$_createMessage)
    ..aOM<Recipe>(1, _omitFieldNames ? '' : 'recipe',
        subBuilder: Recipe.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayPiece clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayPiece copyWith(void Function(PlayPiece) updates) =>
      super.copyWith((message) => updates(message as PlayPiece)) as PlayPiece;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayPiece() / PlayPiece.new instead')
  static PlayPiece create() => PlayPiece._();
  static $pb.GeneratedMessage $_createMessage() => PlayPiece._();
  @$core.override
  PlayPiece createEmptyInstance() => PlayPiece._();
  @$core.pragma('dart2js:noInline')
  static PlayPiece getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlayPiece>(PlayPiece.$_createMessage);
  static PlayPiece? _defaultInstance;

  @$pb.TagNumber(1)
  Recipe get recipe => $_getN(0);
  @$pb.TagNumber(1)
  set recipe(Recipe value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRecipe() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecipe() => $_clearField(1);
  @$pb.TagNumber(1)
  Recipe ensureRecipe() => $_ensure(0);
}

class StopPiece extends $pb.GeneratedMessage {
  factory StopPiece() => StopPiece._();

  StopPiece._();

  factory StopPiece.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopPiece()..mergeFromBuffer(data, registry);
  factory StopPiece.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopPiece()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopPiece',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: StopPiece.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopPiece clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopPiece copyWith(void Function(StopPiece) updates) =>
      super.copyWith((message) => updates(message as StopPiece)) as StopPiece;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopPiece() / StopPiece.new instead')
  static StopPiece create() => StopPiece._();
  static $pb.GeneratedMessage $_createMessage() => StopPiece._();
  @$core.override
  StopPiece createEmptyInstance() => StopPiece._();
  @$core.pragma('dart2js:noInline')
  static StopPiece getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StopPiece>(StopPiece.$_createMessage);
  static StopPiece? _defaultInstance;
}

class Hello extends $pb.GeneratedMessage {
  factory Hello({
    $core.int? protocolVersion,
    $core.String? engineVersion,
    $core.String? firmwareCommit,
    $core.Iterable<$core.String>? capabilities,
  }) {
    final result = Hello._();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (engineVersion != null) result.engineVersion = engineVersion;
    if (firmwareCommit != null) result.firmwareCommit = firmwareCommit;
    if (capabilities != null) result.capabilities.addAll(capabilities);
    return result;
  }

  Hello._();

  factory Hello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hello()..mergeFromBuffer(data, registry);
  factory Hello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Hello()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Hello',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Hello.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'engineVersion')
    ..aOS(3, _omitFieldNames ? '' : 'firmwareCommit')
    ..pPS(4, _omitFieldNames ? '' : 'capabilities')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello copyWith(void Function(Hello) updates) =>
      super.copyWith((message) => updates(message as Hello)) as Hello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Hello() / Hello.new instead')
  static Hello create() => Hello._();
  static $pb.GeneratedMessage $_createMessage() => Hello._();
  @$core.override
  Hello createEmptyInstance() => Hello._();
  @$core.pragma('dart2js:noInline')
  static Hello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Hello>(Hello.$_createMessage);
  static Hello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get engineVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set engineVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEngineVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearEngineVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firmwareCommit => $_getSZ(2);
  @$pb.TagNumber(3)
  set firmwareCommit($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirmwareCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirmwareCommit() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get capabilities => $_getList(3);
}

class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat({
    $core.int? voices,
    $core.double? cpuLoad,
    $fixnum.Int64? underruns,
  }) {
    final result = Heartbeat._();
    if (voices != null) result.voices = voices;
    if (cpuLoad != null) result.cpuLoad = cpuLoad;
    if (underruns != null) result.underruns = underruns;
    return result;
  }

  Heartbeat._();

  factory Heartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Heartbeat()..mergeFromBuffer(data, registry);
  factory Heartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Heartbeat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heartbeat',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Heartbeat.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'voices', fieldType: $pb.PbFieldType.OU3)
    ..aD(2, _omitFieldNames ? '' : 'cpuLoad', fieldType: $pb.PbFieldType.OF)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'underruns', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat copyWith(void Function(Heartbeat) updates) =>
      super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Heartbeat() / Heartbeat.new instead')
  static Heartbeat create() => Heartbeat._();
  static $pb.GeneratedMessage $_createMessage() => Heartbeat._();
  @$core.override
  Heartbeat createEmptyInstance() => Heartbeat._();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Heartbeat>(Heartbeat.$_createMessage);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get voices => $_getIZ(0);
  @$pb.TagNumber(1)
  set voices($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVoices() => $_has(0);
  @$pb.TagNumber(1)
  void clearVoices() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get cpuLoad => $_getN(1);
  @$pb.TagNumber(2)
  set cpuLoad($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCpuLoad() => $_has(1);
  @$pb.TagNumber(2)
  void clearCpuLoad() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get underruns => $_getI64(2);
  @$pb.TagNumber(3)
  set underruns($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUnderruns() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnderruns() => $_clearField(3);
}

class CardProgress extends $pb.GeneratedMessage {
  factory CardProgress({
    $core.int? done,
    $core.int? total,
  }) {
    final result = CardProgress._();
    if (done != null) result.done = done;
    if (total != null) result.total = total;
    return result;
  }

  CardProgress._();

  factory CardProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardProgress()..mergeFromBuffer(data, registry);
  factory CardProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardProgress',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: CardProgress.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'done', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'total', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardProgress copyWith(void Function(CardProgress) updates) =>
      super.copyWith((message) => updates(message as CardProgress))
          as CardProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardProgress() / CardProgress.new instead')
  static CardProgress create() => CardProgress._();
  static $pb.GeneratedMessage $_createMessage() => CardProgress._();
  @$core.override
  CardProgress createEmptyInstance() => CardProgress._();
  @$core.pragma('dart2js:noInline')
  static CardProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CardProgress>(
          CardProgress.$_createMessage);
  static CardProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get done => $_getIZ(0);
  @$pb.TagNumber(1)
  set done($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDone() => $_has(0);
  @$pb.TagNumber(1)
  void clearDone() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get total => $_getIZ(1);
  @$pb.TagNumber(2)
  set total($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotal() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotal() => $_clearField(2);
}

class CardReady extends $pb.GeneratedMessage {
  factory CardReady() => CardReady._();

  CardReady._();

  factory CardReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardReady()..mergeFromBuffer(data, registry);
  factory CardReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardReady()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardReady',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: CardReady.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardReady copyWith(void Function(CardReady) updates) =>
      super.copyWith((message) => updates(message as CardReady)) as CardReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardReady() / CardReady.new instead')
  static CardReady create() => CardReady._();
  static $pb.GeneratedMessage $_createMessage() => CardReady._();
  @$core.override
  CardReady createEmptyInstance() => CardReady._();
  @$core.pragma('dart2js:noInline')
  static CardReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardReady>(CardReady.$_createMessage);
  static CardReady? _defaultInstance;
}

class CardError extends $pb.GeneratedMessage {
  factory CardError({
    $core.String? text,
  }) {
    final result = CardError._();
    if (text != null) result.text = text;
    return result;
  }

  CardError._();

  factory CardError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardError()..mergeFromBuffer(data, registry);
  factory CardError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardError()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardError',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: CardError.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardError copyWith(void Function(CardError) updates) =>
      super.copyWith((message) => updates(message as CardError)) as CardError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardError() / CardError.new instead')
  static CardError create() => CardError._();
  static $pb.GeneratedMessage $_createMessage() => CardError._();
  @$core.override
  CardError createEmptyInstance() => CardError._();
  @$core.pragma('dart2js:noInline')
  static CardError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardError>(CardError.$_createMessage);
  static CardError? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
}

enum CardStatus_State { progress, ready, error, notSet }

class CardStatus extends $pb.GeneratedMessage {
  factory CardStatus({
    CardProgress? progress,
    CardReady? ready,
    CardError? error,
  }) {
    final result = CardStatus._();
    if (progress != null) result.progress = progress;
    if (ready != null) result.ready = ready;
    if (error != null) result.error = error;
    return result;
  }

  CardStatus._();

  factory CardStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardStatus()..mergeFromBuffer(data, registry);
  factory CardStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CardStatus()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, CardStatus_State> _CardStatus_StateByTag = {
    1: CardStatus_State.progress,
    2: CardStatus_State.ready,
    3: CardStatus_State.error,
    0: CardStatus_State.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardStatus',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: CardStatus.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<CardProgress>(1, _omitFieldNames ? '' : 'progress',
        subBuilder: CardProgress.$_createMessage)
    ..aOM<CardReady>(2, _omitFieldNames ? '' : 'ready',
        subBuilder: CardReady.$_createMessage)
    ..aOM<CardError>(3, _omitFieldNames ? '' : 'error',
        subBuilder: CardError.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardStatus copyWith(void Function(CardStatus) updates) =>
      super.copyWith((message) => updates(message as CardStatus)) as CardStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CardStatus() / CardStatus.new instead')
  static CardStatus create() => CardStatus._();
  static $pb.GeneratedMessage $_createMessage() => CardStatus._();
  @$core.override
  CardStatus createEmptyInstance() => CardStatus._();
  @$core.pragma('dart2js:noInline')
  static CardStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardStatus>(CardStatus.$_createMessage);
  static CardStatus? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  CardStatus_State whichState() => _CardStatus_StateByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearState() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  CardProgress get progress => $_getN(0);
  @$pb.TagNumber(1)
  set progress(CardProgress value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProgress() => $_has(0);
  @$pb.TagNumber(1)
  void clearProgress() => $_clearField(1);
  @$pb.TagNumber(1)
  CardProgress ensureProgress() => $_ensure(0);

  @$pb.TagNumber(2)
  CardReady get ready => $_getN(1);
  @$pb.TagNumber(2)
  set ready(CardReady value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReady() => $_has(1);
  @$pb.TagNumber(2)
  void clearReady() => $_clearField(2);
  @$pb.TagNumber(2)
  CardReady ensureReady() => $_ensure(1);

  @$pb.TagNumber(3)
  CardError get error => $_getN(2);
  @$pb.TagNumber(3)
  set error(CardError value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
  @$pb.TagNumber(3)
  CardError ensureError() => $_ensure(2);
}

class PresetEntry extends $pb.GeneratedMessage {
  factory PresetEntry({
    $core.String? path,
    $core.String? name,
  }) {
    final result = PresetEntry._();
    if (path != null) result.path = path;
    if (name != null) result.name = name;
    return result;
  }

  PresetEntry._();

  factory PresetEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PresetEntry()..mergeFromBuffer(data, registry);
  factory PresetEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PresetEntry()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PresetEntry',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: PresetEntry.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PresetEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PresetEntry copyWith(void Function(PresetEntry) updates) =>
      super.copyWith((message) => updates(message as PresetEntry))
          as PresetEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PresetEntry() / PresetEntry.new instead')
  static PresetEntry create() => PresetEntry._();
  static $pb.GeneratedMessage $_createMessage() => PresetEntry._();
  @$core.override
  PresetEntry createEmptyInstance() => PresetEntry._();
  @$core.pragma('dart2js:noInline')
  static PresetEntry getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PresetEntry>(
          PresetEntry.$_createMessage);
  static PresetEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class Catalog extends $pb.GeneratedMessage {
  factory Catalog({
    $core.Iterable<PresetEntry>? synths,
    $core.Iterable<PresetEntry>? kits,
  }) {
    final result = Catalog._();
    if (synths != null) result.synths.addAll(synths);
    if (kits != null) result.kits.addAll(kits);
    return result;
  }

  Catalog._();

  factory Catalog.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Catalog()..mergeFromBuffer(data, registry);
  factory Catalog.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Catalog()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Catalog',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Catalog.$_createMessage)
    ..pPM<PresetEntry>(1, _omitFieldNames ? '' : 'synths',
        subBuilder: PresetEntry.$_createMessage)
    ..pPM<PresetEntry>(2, _omitFieldNames ? '' : 'kits',
        subBuilder: PresetEntry.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Catalog clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Catalog copyWith(void Function(Catalog) updates) =>
      super.copyWith((message) => updates(message as Catalog)) as Catalog;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Catalog() / Catalog.new instead')
  static Catalog create() => Catalog._();
  static $pb.GeneratedMessage $_createMessage() => Catalog._();
  @$core.override
  Catalog createEmptyInstance() => Catalog._();
  @$core.pragma('dart2js:noInline')
  static Catalog getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Catalog>(Catalog.$_createMessage);
  static Catalog? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PresetEntry> get synths => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<PresetEntry> get kits => $_getList(1);
}

class PaletteEntry extends $pb.GeneratedMessage {
  factory PaletteEntry({
    $core.String? path,
    $core.int? weight,
  }) {
    final result = PaletteEntry._();
    if (path != null) result.path = path;
    if (weight != null) result.weight = weight;
    return result;
  }

  PaletteEntry._();

  factory PaletteEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PaletteEntry()..mergeFromBuffer(data, registry);
  factory PaletteEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PaletteEntry()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaletteEntry',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: PaletteEntry.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aI(2, _omitFieldNames ? '' : 'weight', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaletteEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaletteEntry copyWith(void Function(PaletteEntry) updates) =>
      super.copyWith((message) => updates(message as PaletteEntry))
          as PaletteEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PaletteEntry() / PaletteEntry.new instead')
  static PaletteEntry create() => PaletteEntry._();
  static $pb.GeneratedMessage $_createMessage() => PaletteEntry._();
  @$core.override
  PaletteEntry createEmptyInstance() => PaletteEntry._();
  @$core.pragma('dart2js:noInline')
  static PaletteEntry getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PaletteEntry>(
          PaletteEntry.$_createMessage);
  static PaletteEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get weight => $_getIZ(1);
  @$pb.TagNumber(2)
  set weight($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearWeight() => $_clearField(2);
}

class LaneInfo extends $pb.GeneratedMessage {
  factory LaneInfo({
    $core.int? index,
    $core.String? name,
    $core.Iterable<PaletteEntry>? palette,
  }) {
    final result = LaneInfo._();
    if (index != null) result.index = index;
    if (name != null) result.name = name;
    if (palette != null) result.palette.addAll(palette);
    return result;
  }

  LaneInfo._();

  factory LaneInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LaneInfo()..mergeFromBuffer(data, registry);
  factory LaneInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LaneInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LaneInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: LaneInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'index', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPM<PaletteEntry>(3, _omitFieldNames ? '' : 'palette',
        subBuilder: PaletteEntry.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LaneInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LaneInfo copyWith(void Function(LaneInfo) updates) =>
      super.copyWith((message) => updates(message as LaneInfo)) as LaneInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LaneInfo() / LaneInfo.new instead')
  static LaneInfo create() => LaneInfo._();
  static $pb.GeneratedMessage $_createMessage() => LaneInfo._();
  @$core.override
  LaneInfo createEmptyInstance() => LaneInfo._();
  @$core.pragma('dart2js:noInline')
  static LaneInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LaneInfo>(LaneInfo.$_createMessage);
  static LaneInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<PaletteEntry> get palette => $_getList(2);
}

class PartInfo extends $pb.GeneratedMessage {
  factory PartInfo({
    $core.int? index,
    $core.String? name,
    $core.String? role,
    $core.Iterable<PaletteEntry>? palette,
    $core.Iterable<LaneInfo>? lanes,
  }) {
    final result = PartInfo._();
    if (index != null) result.index = index;
    if (name != null) result.name = name;
    if (role != null) result.role = role;
    if (palette != null) result.palette.addAll(palette);
    if (lanes != null) result.lanes.addAll(lanes);
    return result;
  }

  PartInfo._();

  factory PartInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartInfo()..mergeFromBuffer(data, registry);
  factory PartInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PartInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: PartInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'index', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'role')
    ..pPM<PaletteEntry>(4, _omitFieldNames ? '' : 'palette',
        subBuilder: PaletteEntry.$_createMessage)
    ..pPM<LaneInfo>(5, _omitFieldNames ? '' : 'lanes',
        subBuilder: LaneInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartInfo copyWith(void Function(PartInfo) updates) =>
      super.copyWith((message) => updates(message as PartInfo)) as PartInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PartInfo() / PartInfo.new instead')
  static PartInfo create() => PartInfo._();
  static $pb.GeneratedMessage $_createMessage() => PartInfo._();
  @$core.override
  PartInfo createEmptyInstance() => PartInfo._();
  @$core.pragma('dart2js:noInline')
  static PartInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PartInfo>(PartInfo.$_createMessage);
  static PartInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get role => $_getSZ(2);
  @$pb.TagNumber(3)
  set role($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<PaletteEntry> get palette => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<LaneInfo> get lanes => $_getList(4);
}

class GenreInfo extends $pb.GeneratedMessage {
  factory GenreInfo({
    $core.String? id,
    $core.String? name,
    $core.Iterable<PartInfo>? parts,
  }) {
    final result = GenreInfo._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (parts != null) result.parts.addAll(parts);
    return result;
  }

  GenreInfo._();

  factory GenreInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenreInfo()..mergeFromBuffer(data, registry);
  factory GenreInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenreInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenreInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: GenreInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..pPM<PartInfo>(3, _omitFieldNames ? '' : 'parts',
        subBuilder: PartInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenreInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenreInfo copyWith(void Function(GenreInfo) updates) =>
      super.copyWith((message) => updates(message as GenreInfo)) as GenreInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenreInfo() / GenreInfo.new instead')
  static GenreInfo create() => GenreInfo._();
  static $pb.GeneratedMessage $_createMessage() => GenreInfo._();
  @$core.override
  GenreInfo createEmptyInstance() => GenreInfo._();
  @$core.pragma('dart2js:noInline')
  static GenreInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenreInfo>(GenreInfo.$_createMessage);
  static GenreInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<PartInfo> get parts => $_getList(2);
}

class Genres extends $pb.GeneratedMessage {
  factory Genres({
    $core.Iterable<GenreInfo>? genres,
  }) {
    final result = Genres._();
    if (genres != null) result.genres.addAll(genres);
    return result;
  }

  Genres._();

  factory Genres.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Genres()..mergeFromBuffer(data, registry);
  factory Genres.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Genres()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Genres',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Genres.$_createMessage)
    ..pPM<GenreInfo>(1, _omitFieldNames ? '' : 'genres',
        subBuilder: GenreInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Genres clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Genres copyWith(void Function(Genres) updates) =>
      super.copyWith((message) => updates(message as Genres)) as Genres;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Genres() / Genres.new instead')
  static Genres create() => Genres._();
  static $pb.GeneratedMessage $_createMessage() => Genres._();
  @$core.override
  Genres createEmptyInstance() => Genres._();
  @$core.pragma('dart2js:noInline')
  static Genres getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Genres>(Genres.$_createMessage);
  static Genres? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GenreInfo> get genres => $_getList(0);
}

class BindingResult extends $pb.GeneratedMessage {
  factory BindingResult({
    $core.int? channel,
    $core.bool? ok,
    $core.String? error,
  }) {
    final result = BindingResult._();
    if (channel != null) result.channel = channel;
    if (ok != null) result.ok = ok;
    if (error != null) result.error = error;
    return result;
  }

  BindingResult._();

  factory BindingResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BindingResult()..mergeFromBuffer(data, registry);
  factory BindingResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BindingResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BindingResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: BindingResult.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'ok')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindingResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindingResult copyWith(void Function(BindingResult) updates) =>
      super.copyWith((message) => updates(message as BindingResult))
          as BindingResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BindingResult() / BindingResult.new instead')
  static BindingResult create() => BindingResult._();
  static $pb.GeneratedMessage $_createMessage() => BindingResult._();
  @$core.override
  BindingResult createEmptyInstance() => BindingResult._();
  @$core.pragma('dart2js:noInline')
  static BindingResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BindingResult>(
          BindingResult.$_createMessage);
  static BindingResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get channel => $_getIZ(0);
  @$pb.TagNumber(1)
  set channel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get ok => $_getBF(1);
  @$pb.TagNumber(2)
  set ok($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOk() => $_has(1);
  @$pb.TagNumber(2)
  void clearOk() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

class SetupApplied extends $pb.GeneratedMessage {
  factory SetupApplied({
    $core.Iterable<BindingResult>? results,
  }) {
    final result = SetupApplied._();
    if (results != null) result.results.addAll(results);
    return result;
  }

  SetupApplied._();

  factory SetupApplied.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetupApplied()..mergeFromBuffer(data, registry);
  factory SetupApplied.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetupApplied()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetupApplied',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SetupApplied.$_createMessage)
    ..pPM<BindingResult>(1, _omitFieldNames ? '' : 'results',
        subBuilder: BindingResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetupApplied clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetupApplied copyWith(void Function(SetupApplied) updates) =>
      super.copyWith((message) => updates(message as SetupApplied))
          as SetupApplied;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetupApplied() / SetupApplied.new instead')
  static SetupApplied create() => SetupApplied._();
  static $pb.GeneratedMessage $_createMessage() => SetupApplied._();
  @$core.override
  SetupApplied createEmptyInstance() => SetupApplied._();
  @$core.pragma('dart2js:noInline')
  static SetupApplied getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetupApplied>(
          SetupApplied.$_createMessage);
  static SetupApplied? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BindingResult> get results => $_getList(0);
}

class MidiActivity extends $pb.GeneratedMessage {
  factory MidiActivity({
    $core.int? channel,
  }) {
    final result = MidiActivity._();
    if (channel != null) result.channel = channel;
    return result;
  }

  MidiActivity._();

  factory MidiActivity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MidiActivity()..mergeFromBuffer(data, registry);
  factory MidiActivity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MidiActivity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MidiActivity',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: MidiActivity.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MidiActivity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MidiActivity copyWith(void Function(MidiActivity) updates) =>
      super.copyWith((message) => updates(message as MidiActivity))
          as MidiActivity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MidiActivity() / MidiActivity.new instead')
  static MidiActivity create() => MidiActivity._();
  static $pb.GeneratedMessage $_createMessage() => MidiActivity._();
  @$core.override
  MidiActivity createEmptyInstance() => MidiActivity._();
  @$core.pragma('dart2js:noInline')
  static MidiActivity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MidiActivity>(
          MidiActivity.$_createMessage);
  static MidiActivity? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get channel => $_getIZ(0);
  @$pb.TagNumber(1)
  set channel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);
}

class Devices extends $pb.GeneratedMessage {
  factory Devices({
    $core.Iterable<$core.String>? audioOutputs,
    $core.Iterable<$core.String>? midiInputs,
  }) {
    final result = Devices._();
    if (audioOutputs != null) result.audioOutputs.addAll(audioOutputs);
    if (midiInputs != null) result.midiInputs.addAll(midiInputs);
    return result;
  }

  Devices._();

  factory Devices.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Devices()..mergeFromBuffer(data, registry);
  factory Devices.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Devices()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Devices',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Devices.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'audioOutputs')
    ..pPS(2, _omitFieldNames ? '' : 'midiInputs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Devices clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Devices copyWith(void Function(Devices) updates) =>
      super.copyWith((message) => updates(message as Devices)) as Devices;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Devices() / Devices.new instead')
  static Devices create() => Devices._();
  static $pb.GeneratedMessage $_createMessage() => Devices._();
  @$core.override
  Devices createEmptyInstance() => Devices._();
  @$core.pragma('dart2js:noInline')
  static Devices getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Devices>(Devices.$_createMessage);
  static Devices? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get audioOutputs => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get midiInputs => $_getList(1);
}

class Freeze extends $pb.GeneratedMessage {
  factory Freeze({
    $core.String? code,
    $core.String? message,
    $core.String? loaded,
  }) {
    final result = Freeze._();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (loaded != null) result.loaded = loaded;
    return result;
  }

  Freeze._();

  factory Freeze.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Freeze()..mergeFromBuffer(data, registry);
  factory Freeze.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Freeze()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Freeze',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Freeze.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'loaded')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Freeze clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Freeze copyWith(void Function(Freeze) updates) =>
      super.copyWith((message) => updates(message as Freeze)) as Freeze;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Freeze() / Freeze.new instead')
  static Freeze create() => Freeze._();
  static $pb.GeneratedMessage $_createMessage() => Freeze._();
  @$core.override
  Freeze createEmptyInstance() => Freeze._();
  @$core.pragma('dart2js:noInline')
  static Freeze getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Freeze>(Freeze.$_createMessage);
  static Freeze? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get loaded => $_getSZ(2);
  @$pb.TagNumber(3)
  set loaded($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLoaded() => $_has(2);
  @$pb.TagNumber(3)
  void clearLoaded() => $_clearField(3);
}

class ErrorReply extends $pb.GeneratedMessage {
  factory ErrorReply({
    $core.String? command,
    $core.String? message,
  }) {
    final result = ErrorReply._();
    if (command != null) result.command = command;
    if (message != null) result.message = message;
    return result;
  }

  ErrorReply._();

  factory ErrorReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ErrorReply()..mergeFromBuffer(data, registry);
  factory ErrorReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ErrorReply()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ErrorReply',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: ErrorReply.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'command')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorReply copyWith(void Function(ErrorReply) updates) =>
      super.copyWith((message) => updates(message as ErrorReply)) as ErrorReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ErrorReply() / ErrorReply.new instead')
  static ErrorReply create() => ErrorReply._();
  static $pb.GeneratedMessage $_createMessage() => ErrorReply._();
  @$core.override
  ErrorReply createEmptyInstance() => ErrorReply._();
  @$core.pragma('dart2js:noInline')
  static ErrorReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ErrorReply>(ErrorReply.$_createMessage);
  static ErrorReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get command => $_getSZ(0);
  @$pb.TagNumber(1)
  set command($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class RenderProgress extends $pb.GeneratedMessage {
  factory RenderProgress({
    $core.String? id,
    $core.double? doneS,
    $core.double? totalS,
  }) {
    final result = RenderProgress._();
    if (id != null) result.id = id;
    if (doneS != null) result.doneS = doneS;
    if (totalS != null) result.totalS = totalS;
    return result;
  }

  RenderProgress._();

  factory RenderProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderProgress()..mergeFromBuffer(data, registry);
  factory RenderProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderProgress',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: RenderProgress.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aD(2, _omitFieldNames ? '' : 'doneS')
    ..aD(3, _omitFieldNames ? '' : 'totalS')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderProgress copyWith(void Function(RenderProgress) updates) =>
      super.copyWith((message) => updates(message as RenderProgress))
          as RenderProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenderProgress() / RenderProgress.new instead')
  static RenderProgress create() => RenderProgress._();
  static $pb.GeneratedMessage $_createMessage() => RenderProgress._();
  @$core.override
  RenderProgress createEmptyInstance() => RenderProgress._();
  @$core.pragma('dart2js:noInline')
  static RenderProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenderProgress>(
          RenderProgress.$_createMessage);
  static RenderProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get doneS => $_getN(1);
  @$pb.TagNumber(2)
  set doneS($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDoneS() => $_has(1);
  @$pb.TagNumber(2)
  void clearDoneS() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get totalS => $_getN(2);
  @$pb.TagNumber(3)
  set totalS($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalS() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalS() => $_clearField(3);
}

class SectionMarker extends $pb.GeneratedMessage {
  factory SectionMarker({
    $core.String? name,
    $core.double? timeS,
  }) {
    final result = SectionMarker._();
    if (name != null) result.name = name;
    if (timeS != null) result.timeS = timeS;
    return result;
  }

  SectionMarker._();

  factory SectionMarker.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SectionMarker()..mergeFromBuffer(data, registry);
  factory SectionMarker.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SectionMarker()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SectionMarker',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: SectionMarker.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aD(2, _omitFieldNames ? '' : 'timeS')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SectionMarker clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SectionMarker copyWith(void Function(SectionMarker) updates) =>
      super.copyWith((message) => updates(message as SectionMarker))
          as SectionMarker;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SectionMarker() / SectionMarker.new instead')
  static SectionMarker create() => SectionMarker._();
  static $pb.GeneratedMessage $_createMessage() => SectionMarker._();
  @$core.override
  SectionMarker createEmptyInstance() => SectionMarker._();
  @$core.pragma('dart2js:noInline')
  static SectionMarker getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SectionMarker>(
          SectionMarker.$_createMessage);
  static SectionMarker? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get timeS => $_getN(1);
  @$pb.TagNumber(2)
  set timeS($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimeS() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimeS() => $_clearField(2);
}

class PeakPair extends $pb.GeneratedMessage {
  factory PeakPair({
    $core.double? min,
    $core.double? max,
  }) {
    final result = PeakPair._();
    if (min != null) result.min = min;
    if (max != null) result.max = max;
    return result;
  }

  PeakPair._();

  factory PeakPair.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeakPair()..mergeFromBuffer(data, registry);
  factory PeakPair.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeakPair()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeakPair',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: PeakPair.$_createMessage)
    ..aD(1, _omitFieldNames ? '' : 'min', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'max', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeakPair clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeakPair copyWith(void Function(PeakPair) updates) =>
      super.copyWith((message) => updates(message as PeakPair)) as PeakPair;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PeakPair() / PeakPair.new instead')
  static PeakPair create() => PeakPair._();
  static $pb.GeneratedMessage $_createMessage() => PeakPair._();
  @$core.override
  PeakPair createEmptyInstance() => PeakPair._();
  @$core.pragma('dart2js:noInline')
  static PeakPair getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeakPair>(PeakPair.$_createMessage);
  static PeakPair? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get min => $_getN(0);
  @$pb.TagNumber(1)
  set min($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMin() => $_has(0);
  @$pb.TagNumber(1)
  void clearMin() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get max => $_getN(1);
  @$pb.TagNumber(2)
  set max($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMax() => $_has(1);
  @$pb.TagNumber(2)
  void clearMax() => $_clearField(2);
}

enum TimelineNote_Target { part, lane, notSet }

class TimelineNote extends $pb.GeneratedMessage {
  factory TimelineNote({
    $core.int? part,
    $core.int? lane,
    $core.double? startS,
    $core.double? lengthS,
    $core.int? pitch,
    $core.int? velocity,
  }) {
    final result = TimelineNote._();
    if (part != null) result.part = part;
    if (lane != null) result.lane = lane;
    if (startS != null) result.startS = startS;
    if (lengthS != null) result.lengthS = lengthS;
    if (pitch != null) result.pitch = pitch;
    if (velocity != null) result.velocity = velocity;
    return result;
  }

  TimelineNote._();

  factory TimelineNote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineNote()..mergeFromBuffer(data, registry);
  factory TimelineNote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineNote()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TimelineNote_Target>
      _TimelineNote_TargetByTag = {
    1: TimelineNote_Target.part,
    2: TimelineNote_Target.lane,
    0: TimelineNote_Target.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimelineNote',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: TimelineNote.$_createMessage)
    ..oo(0, [1, 2])
    ..aI(1, _omitFieldNames ? '' : 'part', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'lane', fieldType: $pb.PbFieldType.OU3)
    ..aD(3, _omitFieldNames ? '' : 'startS')
    ..aD(4, _omitFieldNames ? '' : 'lengthS')
    ..aI(5, _omitFieldNames ? '' : 'pitch', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'velocity', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineNote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineNote copyWith(void Function(TimelineNote) updates) =>
      super.copyWith((message) => updates(message as TimelineNote))
          as TimelineNote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimelineNote() / TimelineNote.new instead')
  static TimelineNote create() => TimelineNote._();
  static $pb.GeneratedMessage $_createMessage() => TimelineNote._();
  @$core.override
  TimelineNote createEmptyInstance() => TimelineNote._();
  @$core.pragma('dart2js:noInline')
  static TimelineNote getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimelineNote>(
          TimelineNote.$_createMessage);
  static TimelineNote? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  TimelineNote_Target whichTarget() =>
      _TimelineNote_TargetByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTarget() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.int get part => $_getIZ(0);
  @$pb.TagNumber(1)
  set part($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPart() => $_has(0);
  @$pb.TagNumber(1)
  void clearPart() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get lane => $_getIZ(1);
  @$pb.TagNumber(2)
  set lane($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLane() => $_has(1);
  @$pb.TagNumber(2)
  void clearLane() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get startS => $_getN(2);
  @$pb.TagNumber(3)
  set startS($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartS() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartS() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get lengthS => $_getN(3);
  @$pb.TagNumber(4)
  set lengthS($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLengthS() => $_has(3);
  @$pb.TagNumber(4)
  void clearLengthS() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get pitch => $_getIZ(4);
  @$pb.TagNumber(5)
  set pitch($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPitch() => $_has(4);
  @$pb.TagNumber(5)
  void clearPitch() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get velocity => $_getIZ(5);
  @$pb.TagNumber(6)
  set velocity($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVelocity() => $_has(5);
  @$pb.TagNumber(6)
  void clearVelocity() => $_clearField(6);
}

class RenderDone extends $pb.GeneratedMessage {
  factory RenderDone({
    $core.String? id,
    $core.String? wavPath,
    $core.double? durationS,
    Recipe? recipe,
    $core.Iterable<SectionMarker>? sections,
    $core.Iterable<PeakPair>? peaks,
    $core.Iterable<TimelineNote>? notes,
    $core.Iterable<$core.String>? warnings,
    $core.int? peakVoices,
  }) {
    final result = RenderDone._();
    if (id != null) result.id = id;
    if (wavPath != null) result.wavPath = wavPath;
    if (durationS != null) result.durationS = durationS;
    if (recipe != null) result.recipe = recipe;
    if (sections != null) result.sections.addAll(sections);
    if (peaks != null) result.peaks.addAll(peaks);
    if (notes != null) result.notes.addAll(notes);
    if (warnings != null) result.warnings.addAll(warnings);
    if (peakVoices != null) result.peakVoices = peakVoices;
    return result;
  }

  RenderDone._();

  factory RenderDone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderDone()..mergeFromBuffer(data, registry);
  factory RenderDone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderDone()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderDone',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: RenderDone.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'wavPath')
    ..aD(3, _omitFieldNames ? '' : 'durationS')
    ..aOM<Recipe>(4, _omitFieldNames ? '' : 'recipe',
        subBuilder: Recipe.$_createMessage)
    ..pPM<SectionMarker>(5, _omitFieldNames ? '' : 'sections',
        subBuilder: SectionMarker.$_createMessage)
    ..pPM<PeakPair>(6, _omitFieldNames ? '' : 'peaks',
        subBuilder: PeakPair.$_createMessage)
    ..pPM<TimelineNote>(7, _omitFieldNames ? '' : 'notes',
        subBuilder: TimelineNote.$_createMessage)
    ..pPS(8, _omitFieldNames ? '' : 'warnings')
    ..aI(9, _omitFieldNames ? '' : 'peakVoices', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderDone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderDone copyWith(void Function(RenderDone) updates) =>
      super.copyWith((message) => updates(message as RenderDone)) as RenderDone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenderDone() / RenderDone.new instead')
  static RenderDone create() => RenderDone._();
  static $pb.GeneratedMessage $_createMessage() => RenderDone._();
  @$core.override
  RenderDone createEmptyInstance() => RenderDone._();
  @$core.pragma('dart2js:noInline')
  static RenderDone getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenderDone>(RenderDone.$_createMessage);
  static RenderDone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get wavPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set wavPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWavPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWavPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get durationS => $_getN(2);
  @$pb.TagNumber(3)
  set durationS($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationS() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationS() => $_clearField(3);

  @$pb.TagNumber(4)
  Recipe get recipe => $_getN(3);
  @$pb.TagNumber(4)
  set recipe(Recipe value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRecipe() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecipe() => $_clearField(4);
  @$pb.TagNumber(4)
  Recipe ensureRecipe() => $_ensure(3);

  @$pb.TagNumber(5)
  $pb.PbList<SectionMarker> get sections => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<PeakPair> get peaks => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<TimelineNote> get notes => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get warnings => $_getList(7);

  @$pb.TagNumber(9)
  $core.int get peakVoices => $_getIZ(8);
  @$pb.TagNumber(9)
  set peakVoices($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPeakVoices() => $_has(8);
  @$pb.TagNumber(9)
  void clearPeakVoices() => $_clearField(9);
}

class RenderFailed extends $pb.GeneratedMessage {
  factory RenderFailed({
    $core.String? id,
    $core.String? error,
    $core.String? freezeCode,
  }) {
    final result = RenderFailed._();
    if (id != null) result.id = id;
    if (error != null) result.error = error;
    if (freezeCode != null) result.freezeCode = freezeCode;
    return result;
  }

  RenderFailed._();

  factory RenderFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderFailed()..mergeFromBuffer(data, registry);
  factory RenderFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenderFailed()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenderFailed',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: RenderFailed.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..aOS(3, _omitFieldNames ? '' : 'freezeCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderFailed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenderFailed copyWith(void Function(RenderFailed) updates) =>
      super.copyWith((message) => updates(message as RenderFailed))
          as RenderFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenderFailed() / RenderFailed.new instead')
  static RenderFailed create() => RenderFailed._();
  static $pb.GeneratedMessage $_createMessage() => RenderFailed._();
  @$core.override
  RenderFailed createEmptyInstance() => RenderFailed._();
  @$core.pragma('dart2js:noInline')
  static RenderFailed getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenderFailed>(
          RenderFailed.$_createMessage);
  static RenderFailed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get freezeCode => $_getSZ(2);
  @$pb.TagNumber(3)
  set freezeCode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFreezeCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearFreezeCode() => $_clearField(3);
}

class Position extends $pb.GeneratedMessage {
  factory Position({
    $core.String? wavPath,
    $core.double? timeS,
  }) {
    final result = Position._();
    if (wavPath != null) result.wavPath = wavPath;
    if (timeS != null) result.timeS = timeS;
    return result;
  }

  Position._();

  factory Position.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Position()..mergeFromBuffer(data, registry);
  factory Position.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Position()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Position',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'deluge.engine.proto'),
      createEmptyInstance: Position.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'wavPath')
    ..aD(2, _omitFieldNames ? '' : 'timeS')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position copyWith(void Function(Position) updates) =>
      super.copyWith((message) => updates(message as Position)) as Position;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Position() / Position.new instead')
  static Position create() => Position._();
  static $pb.GeneratedMessage $_createMessage() => Position._();
  @$core.override
  Position createEmptyInstance() => Position._();
  @$core.pragma('dart2js:noInline')
  static Position getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Position>(Position.$_createMessage);
  static Position? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get wavPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set wavPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWavPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearWavPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get timeS => $_getN(1);
  @$pb.TagNumber(2)
  set timeS($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimeS() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimeS() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
