// This is a generated file - do not edit.
//
// Generated from engine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use protocolVersionDescriptor instead')
const ProtocolVersion$json = {
  '1': 'ProtocolVersion',
  '2': [
    {'1': 'PROTOCOL_VERSION_UNSPECIFIED', '2': 0},
    {'1': 'PROTOCOL_VERSION_CURRENT', '2': 1},
  ],
};

/// Descriptor for `ProtocolVersion`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List protocolVersionDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2NvbFZlcnNpb24SIAocUFJPVE9DT0xfVkVSU0lPTl9VTlNQRUNJRklFRBAAEhwKGF'
    'BST1RPQ09MX1ZFUlNJT05fQ1VSUkVOVBAB');

@$core.Deprecated('Use toEngineDescriptor instead')
const ToEngine$json = {
  '1': 'ToEngine',
  '2': [
    {
      '1': 'set_card',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.SetCard',
      '9': 0,
      '10': 'setCard'
    },
    {
      '1': 'set_setup',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.SetSetup',
      '9': 0,
      '10': 'setSetup'
    },
    {
      '1': 'audition',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Audition',
      '9': 0,
      '10': 'audition'
    },
    {
      '1': 'note',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Note',
      '9': 0,
      '10': 'note'
    },
    {
      '1': 'set_devices',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.SetDevices',
      '9': 0,
      '10': 'setDevices'
    },
    {
      '1': 'shutdown',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Shutdown',
      '9': 0,
      '10': 'shutdown'
    },
    {
      '1': 'render_piece',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.RenderPiece',
      '9': 0,
      '10': 'renderPiece'
    },
    {
      '1': 'cancel_render',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.CancelRender',
      '9': 0,
      '10': 'cancelRender'
    },
    {
      '1': 'play',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Play',
      '9': 0,
      '10': 'play'
    },
    {
      '1': 'seek',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Seek',
      '9': 0,
      '10': 'seek'
    },
    {
      '1': 'stop',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Stop',
      '9': 0,
      '10': 'stop'
    },
    {
      '1': 'play_piece',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.PlayPiece',
      '9': 0,
      '10': 'playPiece'
    },
    {
      '1': 'stop_piece',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.StopPiece',
      '9': 0,
      '10': 'stopPiece'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `ToEngine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toEngineDescriptor = $convert.base64Decode(
    'CghUb0VuZ2luZRI5CghzZXRfY2FyZBgBIAEoCzIcLmRlbHVnZS5lbmdpbmUucHJvdG8uU2V0Q2'
    'FyZEgAUgdzZXRDYXJkEjwKCXNldF9zZXR1cBgCIAEoCzIdLmRlbHVnZS5lbmdpbmUucHJvdG8u'
    'U2V0U2V0dXBIAFIIc2V0U2V0dXASOwoIYXVkaXRpb24YAyABKAsyHS5kZWx1Z2UuZW5naW5lLn'
    'Byb3RvLkF1ZGl0aW9uSABSCGF1ZGl0aW9uEi8KBG5vdGUYBCABKAsyGS5kZWx1Z2UuZW5naW5l'
    'LnByb3RvLk5vdGVIAFIEbm90ZRJCCgtzZXRfZGV2aWNlcxgFIAEoCzIfLmRlbHVnZS5lbmdpbm'
    'UucHJvdG8uU2V0RGV2aWNlc0gAUgpzZXREZXZpY2VzEjsKCHNodXRkb3duGAYgASgLMh0uZGVs'
    'dWdlLmVuZ2luZS5wcm90by5TaHV0ZG93bkgAUghzaHV0ZG93bhJFCgxyZW5kZXJfcGllY2UYBy'
    'ABKAsyIC5kZWx1Z2UuZW5naW5lLnByb3RvLlJlbmRlclBpZWNlSABSC3JlbmRlclBpZWNlEkgK'
    'DWNhbmNlbF9yZW5kZXIYCCABKAsyIS5kZWx1Z2UuZW5naW5lLnByb3RvLkNhbmNlbFJlbmRlck'
    'gAUgxjYW5jZWxSZW5kZXISLwoEcGxheRgJIAEoCzIZLmRlbHVnZS5lbmdpbmUucHJvdG8uUGxh'
    'eUgAUgRwbGF5Ei8KBHNlZWsYCiABKAsyGS5kZWx1Z2UuZW5naW5lLnByb3RvLlNlZWtIAFIEc2'
    'VlaxIvCgRzdG9wGAsgASgLMhkuZGVsdWdlLmVuZ2luZS5wcm90by5TdG9wSABSBHN0b3ASPwoK'
    'cGxheV9waWVjZRgMIAEoCzIeLmRlbHVnZS5lbmdpbmUucHJvdG8uUGxheVBpZWNlSABSCXBsYX'
    'lQaWVjZRI/CgpzdG9wX3BpZWNlGA0gASgLMh4uZGVsdWdlLmVuZ2luZS5wcm90by5TdG9wUGll'
    'Y2VIAFIJc3RvcFBpZWNlQgYKBGtpbmQ=');

@$core.Deprecated('Use fromEngineDescriptor instead')
const FromEngine$json = {
  '1': 'FromEngine',
  '2': [
    {
      '1': 'hello',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Hello',
      '9': 0,
      '10': 'hello'
    },
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'card_status',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.CardStatus',
      '9': 0,
      '10': 'cardStatus'
    },
    {
      '1': 'catalog',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Catalog',
      '9': 0,
      '10': 'catalog'
    },
    {
      '1': 'genres',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Genres',
      '9': 0,
      '10': 'genres'
    },
    {
      '1': 'setup_applied',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.SetupApplied',
      '9': 0,
      '10': 'setupApplied'
    },
    {
      '1': 'midi_activity',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.MidiActivity',
      '9': 0,
      '10': 'midiActivity'
    },
    {
      '1': 'devices',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Devices',
      '9': 0,
      '10': 'devices'
    },
    {
      '1': 'freeze',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Freeze',
      '9': 0,
      '10': 'freeze'
    },
    {
      '1': 'render_progress',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.RenderProgress',
      '9': 0,
      '10': 'renderProgress'
    },
    {
      '1': 'render_done',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.RenderDone',
      '9': 0,
      '10': 'renderDone'
    },
    {
      '1': 'render_failed',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.RenderFailed',
      '9': 0,
      '10': 'renderFailed'
    },
    {
      '1': 'position',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Position',
      '9': 0,
      '10': 'position'
    },
    {
      '1': 'error',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.ErrorReply',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `FromEngine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fromEngineDescriptor = $convert.base64Decode(
    'CgpGcm9tRW5naW5lEjIKBWhlbGxvGAEgASgLMhouZGVsdWdlLmVuZ2luZS5wcm90by5IZWxsb0'
    'gAUgVoZWxsbxI+CgloZWFydGJlYXQYAiABKAsyHi5kZWx1Z2UuZW5naW5lLnByb3RvLkhlYXJ0'
    'YmVhdEgAUgloZWFydGJlYXQSQgoLY2FyZF9zdGF0dXMYAyABKAsyHy5kZWx1Z2UuZW5naW5lLn'
    'Byb3RvLkNhcmRTdGF0dXNIAFIKY2FyZFN0YXR1cxI4CgdjYXRhbG9nGAQgASgLMhwuZGVsdWdl'
    'LmVuZ2luZS5wcm90by5DYXRhbG9nSABSB2NhdGFsb2cSNQoGZ2VucmVzGAUgASgLMhsuZGVsdW'
    'dlLmVuZ2luZS5wcm90by5HZW5yZXNIAFIGZ2VucmVzEkgKDXNldHVwX2FwcGxpZWQYBiABKAsy'
    'IS5kZWx1Z2UuZW5naW5lLnByb3RvLlNldHVwQXBwbGllZEgAUgxzZXR1cEFwcGxpZWQSSAoNbW'
    'lkaV9hY3Rpdml0eRgHIAEoCzIhLmRlbHVnZS5lbmdpbmUucHJvdG8uTWlkaUFjdGl2aXR5SABS'
    'DG1pZGlBY3Rpdml0eRI4CgdkZXZpY2VzGAggASgLMhwuZGVsdWdlLmVuZ2luZS5wcm90by5EZX'
    'ZpY2VzSABSB2RldmljZXMSNQoGZnJlZXplGAkgASgLMhsuZGVsdWdlLmVuZ2luZS5wcm90by5G'
    'cmVlemVIAFIGZnJlZXplEk4KD3JlbmRlcl9wcm9ncmVzcxgKIAEoCzIjLmRlbHVnZS5lbmdpbm'
    'UucHJvdG8uUmVuZGVyUHJvZ3Jlc3NIAFIOcmVuZGVyUHJvZ3Jlc3MSQgoLcmVuZGVyX2RvbmUY'
    'CyABKAsyHy5kZWx1Z2UuZW5naW5lLnByb3RvLlJlbmRlckRvbmVIAFIKcmVuZGVyRG9uZRJICg'
    '1yZW5kZXJfZmFpbGVkGAwgASgLMiEuZGVsdWdlLmVuZ2luZS5wcm90by5SZW5kZXJGYWlsZWRI'
    'AFIMcmVuZGVyRmFpbGVkEjsKCHBvc2l0aW9uGA0gASgLMh0uZGVsdWdlLmVuZ2luZS5wcm90by'
    '5Qb3NpdGlvbkgAUghwb3NpdGlvbhI3CgVlcnJvchgOIAEoCzIfLmRlbHVnZS5lbmdpbmUucHJv'
    'dG8uRXJyb3JSZXBseUgAUgVlcnJvckIGCgRraW5k');

@$core.Deprecated('Use setCardDescriptor instead')
const SetCard$json = {
  '1': 'SetCard',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `SetCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setCardDescriptor =
    $convert.base64Decode('CgdTZXRDYXJkEhYKBmZvbGRlchgBIAEoCVIGZm9sZGVy');

@$core.Deprecated('Use setupBindingDescriptor instead')
const SetupBinding$json = {
  '1': 'SetupBinding',
  '2': [
    {'1': 'channel', '3': 1, '4': 1, '5': 13, '10': 'channel'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `SetupBinding`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setupBindingDescriptor = $convert.base64Decode(
    'CgxTZXR1cEJpbmRpbmcSGAoHY2hhbm5lbBgBIAEoDVIHY2hhbm5lbBISCgRwYXRoGAIgASgJUg'
    'RwYXRo');

@$core.Deprecated('Use setSetupDescriptor instead')
const SetSetup$json = {
  '1': 'SetSetup',
  '2': [
    {
      '1': 'bindings',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.SetupBinding',
      '10': 'bindings'
    },
  ],
};

/// Descriptor for `SetSetup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSetupDescriptor = $convert.base64Decode(
    'CghTZXRTZXR1cBI9CghiaW5kaW5ncxgBIAMoCzIhLmRlbHVnZS5lbmdpbmUucHJvdG8uU2V0dX'
    'BCaW5kaW5nUghiaW5kaW5ncw==');

@$core.Deprecated('Use auditionDescriptor instead')
const Audition$json = {
  '1': 'Audition',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'note', '3': 2, '4': 1, '5': 13, '10': 'note'},
    {'1': 'velocity', '3': 3, '4': 1, '5': 13, '10': 'velocity'},
    {'1': 'ms', '3': 4, '4': 1, '5': 13, '10': 'ms'},
  ],
};

/// Descriptor for `Audition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List auditionDescriptor = $convert.base64Decode(
    'CghBdWRpdGlvbhISCgRwYXRoGAEgASgJUgRwYXRoEhIKBG5vdGUYAiABKA1SBG5vdGUSGgoIdm'
    'Vsb2NpdHkYAyABKA1SCHZlbG9jaXR5Eg4KAm1zGAQgASgNUgJtcw==');

@$core.Deprecated('Use noteDescriptor instead')
const Note$json = {
  '1': 'Note',
  '2': [
    {'1': 'channel', '3': 1, '4': 1, '5': 13, '10': 'channel'},
    {'1': 'note', '3': 2, '4': 1, '5': 13, '10': 'note'},
    {'1': 'velocity', '3': 3, '4': 1, '5': 13, '10': 'velocity'},
    {'1': 'on', '3': 4, '4': 1, '5': 8, '10': 'on'},
  ],
};

/// Descriptor for `Note`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List noteDescriptor = $convert.base64Decode(
    'CgROb3RlEhgKB2NoYW5uZWwYASABKA1SB2NoYW5uZWwSEgoEbm90ZRgCIAEoDVIEbm90ZRIaCg'
    'h2ZWxvY2l0eRgDIAEoDVIIdmVsb2NpdHkSDgoCb24YBCABKAhSAm9u');

@$core.Deprecated('Use setDevicesDescriptor instead')
const SetDevices$json = {
  '1': 'SetDevices',
  '2': [
    {'1': 'audio_output', '3': 1, '4': 1, '5': 9, '10': 'audioOutput'},
    {'1': 'midi_inputs', '3': 2, '4': 3, '5': 9, '10': 'midiInputs'},
  ],
};

/// Descriptor for `SetDevices`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDevicesDescriptor = $convert.base64Decode(
    'CgpTZXREZXZpY2VzEiEKDGF1ZGlvX291dHB1dBgBIAEoCVILYXVkaW9PdXRwdXQSHwoLbWlkaV'
    '9pbnB1dHMYAiADKAlSCm1pZGlJbnB1dHM=');

@$core.Deprecated('Use shutdownDescriptor instead')
const Shutdown$json = {
  '1': 'Shutdown',
};

/// Descriptor for `Shutdown`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shutdownDescriptor =
    $convert.base64Decode('CghTaHV0ZG93bg==');

@$core.Deprecated('Use soundPickDescriptor instead')
const SoundPick$json = {
  '1': 'SoundPick',
  '2': [
    {'1': 'part', '3': 1, '4': 1, '5': 13, '9': 0, '10': 'part'},
    {'1': 'lane', '3': 2, '4': 1, '5': 13, '9': 0, '10': 'lane'},
    {'1': 'path', '3': 3, '4': 1, '5': 9, '10': 'path'},
  ],
  '8': [
    {'1': 'target'},
  ],
};

/// Descriptor for `SoundPick`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List soundPickDescriptor = $convert.base64Decode(
    'CglTb3VuZFBpY2sSFAoEcGFydBgBIAEoDUgAUgRwYXJ0EhQKBGxhbmUYAiABKA1IAFIEbGFuZR'
    'ISCgRwYXRoGAMgASgJUgRwYXRoQggKBnRhcmdldA==');

@$core.Deprecated('Use recipeDescriptor instead')
const Recipe$json = {
  '1': 'Recipe',
  '2': [
    {'1': 'genre', '3': 1, '4': 1, '5': 9, '10': 'genre'},
    {'1': 'seed', '3': 2, '4': 1, '5': 13, '10': 'seed'},
    {
      '1': 'entropy',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'entropy',
      '17': true
    },
    {'1': 'macros', '3': 4, '4': 3, '5': 5, '10': 'macros'},
    {'1': 'tempo', '3': 5, '4': 1, '5': 1, '9': 1, '10': 'tempo', '17': true},
    {'1': 'key', '3': 6, '4': 1, '5': 13, '9': 2, '10': 'key', '17': true},
    {'1': 'scale', '3': 7, '4': 1, '5': 13, '9': 3, '10': 'scale', '17': true},
    {'1': 'swing', '3': 8, '4': 1, '5': 5, '9': 4, '10': 'swing', '17': true},
    {
      '1': 'picks',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.SoundPick',
      '10': 'picks'
    },
    {
      '1': 'scale_name',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'scaleName',
      '17': true
    },
  ],
  '8': [
    {'1': '_entropy'},
    {'1': '_tempo'},
    {'1': '_key'},
    {'1': '_scale'},
    {'1': '_swing'},
    {'1': '_scale_name'},
  ],
};

/// Descriptor for `Recipe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recipeDescriptor = $convert.base64Decode(
    'CgZSZWNpcGUSFAoFZ2VucmUYASABKAlSBWdlbnJlEhIKBHNlZWQYAiABKA1SBHNlZWQSHQoHZW'
    '50cm9weRgDIAEoDUgAUgdlbnRyb3B5iAEBEhYKBm1hY3JvcxgEIAMoBVIGbWFjcm9zEhkKBXRl'
    'bXBvGAUgASgBSAFSBXRlbXBviAEBEhUKA2tleRgGIAEoDUgCUgNrZXmIAQESGQoFc2NhbGUYBy'
    'ABKA1IA1IFc2NhbGWIAQESGQoFc3dpbmcYCCABKAVIBFIFc3dpbmeIAQESNAoFcGlja3MYCSAD'
    'KAsyHi5kZWx1Z2UuZW5naW5lLnByb3RvLlNvdW5kUGlja1IFcGlja3MSIgoKc2NhbGVfbmFtZR'
    'gKIAEoCUgFUglzY2FsZU5hbWWIAQFCCgoIX2VudHJvcHlCCAoGX3RlbXBvQgYKBF9rZXlCCAoG'
    'X3NjYWxlQggKBl9zd2luZ0INCgtfc2NhbGVfbmFtZQ==');

@$core.Deprecated('Use renderPieceDescriptor instead')
const RenderPiece$json = {
  '1': 'RenderPiece',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'recipe',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Recipe',
      '10': 'recipe'
    },
    {'1': 'length_s', '3': 3, '4': 1, '5': 1, '10': 'lengthS'},
    {'1': 'wav_path', '3': 4, '4': 1, '5': 9, '10': 'wavPath'},
  ],
};

/// Descriptor for `RenderPiece`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderPieceDescriptor = $convert.base64Decode(
    'CgtSZW5kZXJQaWVjZRIOCgJpZBgBIAEoCVICaWQSMwoGcmVjaXBlGAIgASgLMhsuZGVsdWdlLm'
    'VuZ2luZS5wcm90by5SZWNpcGVSBnJlY2lwZRIZCghsZW5ndGhfcxgDIAEoAVIHbGVuZ3RoUxIZ'
    'Cgh3YXZfcGF0aBgEIAEoCVIHd2F2UGF0aA==');

@$core.Deprecated('Use cancelRenderDescriptor instead')
const CancelRender$json = {
  '1': 'CancelRender',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `CancelRender`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelRenderDescriptor =
    $convert.base64Decode('CgxDYW5jZWxSZW5kZXISDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use playDescriptor instead')
const Play$json = {
  '1': 'Play',
  '2': [
    {'1': 'wav_path', '3': 1, '4': 1, '5': 9, '10': 'wavPath'},
    {'1': 'position_s', '3': 2, '4': 1, '5': 1, '10': 'positionS'},
  ],
};

/// Descriptor for `Play`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playDescriptor = $convert.base64Decode(
    'CgRQbGF5EhkKCHdhdl9wYXRoGAEgASgJUgd3YXZQYXRoEh0KCnBvc2l0aW9uX3MYAiABKAFSCX'
    'Bvc2l0aW9uUw==');

@$core.Deprecated('Use seekDescriptor instead')
const Seek$json = {
  '1': 'Seek',
  '2': [
    {'1': 'position_s', '3': 1, '4': 1, '5': 1, '10': 'positionS'},
  ],
};

/// Descriptor for `Seek`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seekDescriptor = $convert
    .base64Decode('CgRTZWVrEh0KCnBvc2l0aW9uX3MYASABKAFSCXBvc2l0aW9uUw==');

@$core.Deprecated('Use stopDescriptor instead')
const Stop$json = {
  '1': 'Stop',
};

/// Descriptor for `Stop`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopDescriptor = $convert.base64Decode('CgRTdG9w');

@$core.Deprecated('Use playPieceDescriptor instead')
const PlayPiece$json = {
  '1': 'PlayPiece',
  '2': [
    {
      '1': 'recipe',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Recipe',
      '10': 'recipe'
    },
  ],
};

/// Descriptor for `PlayPiece`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playPieceDescriptor = $convert.base64Decode(
    'CglQbGF5UGllY2USMwoGcmVjaXBlGAEgASgLMhsuZGVsdWdlLmVuZ2luZS5wcm90by5SZWNpcG'
    'VSBnJlY2lwZQ==');

@$core.Deprecated('Use stopPieceDescriptor instead')
const StopPiece$json = {
  '1': 'StopPiece',
};

/// Descriptor for `StopPiece`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopPieceDescriptor =
    $convert.base64Decode('CglTdG9wUGllY2U=');

@$core.Deprecated('Use helloDescriptor instead')
const Hello$json = {
  '1': 'Hello',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'engine_version', '3': 2, '4': 1, '5': 9, '10': 'engineVersion'},
    {'1': 'firmware_commit', '3': 3, '4': 1, '5': 9, '10': 'firmwareCommit'},
    {'1': 'capabilities', '3': 4, '4': 3, '5': 9, '10': 'capabilities'},
  ],
};

/// Descriptor for `Hello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloDescriptor = $convert.base64Decode(
    'CgVIZWxsbxIpChBwcm90b2NvbF92ZXJzaW9uGAEgASgNUg9wcm90b2NvbFZlcnNpb24SJQoOZW'
    '5naW5lX3ZlcnNpb24YAiABKAlSDWVuZ2luZVZlcnNpb24SJwoPZmlybXdhcmVfY29tbWl0GAMg'
    'ASgJUg5maXJtd2FyZUNvbW1pdBIiCgxjYXBhYmlsaXRpZXMYBCADKAlSDGNhcGFiaWxpdGllcw'
    '==');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'voices', '3': 1, '4': 1, '5': 13, '10': 'voices'},
    {'1': 'cpu_load', '3': 2, '4': 1, '5': 2, '10': 'cpuLoad'},
    {'1': 'underruns', '3': 3, '4': 1, '5': 4, '10': 'underruns'},
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor = $convert.base64Decode(
    'CglIZWFydGJlYXQSFgoGdm9pY2VzGAEgASgNUgZ2b2ljZXMSGQoIY3B1X2xvYWQYAiABKAJSB2'
    'NwdUxvYWQSHAoJdW5kZXJydW5zGAMgASgEUgl1bmRlcnJ1bnM=');

@$core.Deprecated('Use cardProgressDescriptor instead')
const CardProgress$json = {
  '1': 'CardProgress',
  '2': [
    {'1': 'done', '3': 1, '4': 1, '5': 13, '10': 'done'},
    {'1': 'total', '3': 2, '4': 1, '5': 13, '10': 'total'},
  ],
};

/// Descriptor for `CardProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardProgressDescriptor = $convert.base64Decode(
    'CgxDYXJkUHJvZ3Jlc3MSEgoEZG9uZRgBIAEoDVIEZG9uZRIUCgV0b3RhbBgCIAEoDVIFdG90YW'
    'w=');

@$core.Deprecated('Use cardReadyDescriptor instead')
const CardReady$json = {
  '1': 'CardReady',
};

/// Descriptor for `CardReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardReadyDescriptor =
    $convert.base64Decode('CglDYXJkUmVhZHk=');

@$core.Deprecated('Use cardErrorDescriptor instead')
const CardError$json = {
  '1': 'CardError',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `CardError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardErrorDescriptor =
    $convert.base64Decode('CglDYXJkRXJyb3ISEgoEdGV4dBgBIAEoCVIEdGV4dA==');

@$core.Deprecated('Use cardStatusDescriptor instead')
const CardStatus$json = {
  '1': 'CardStatus',
  '2': [
    {
      '1': 'progress',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.CardProgress',
      '9': 0,
      '10': 'progress'
    },
    {
      '1': 'ready',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.CardReady',
      '9': 0,
      '10': 'ready'
    },
    {
      '1': 'error',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.CardError',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'state'},
  ],
};

/// Descriptor for `CardStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardStatusDescriptor = $convert.base64Decode(
    'CgpDYXJkU3RhdHVzEj8KCHByb2dyZXNzGAEgASgLMiEuZGVsdWdlLmVuZ2luZS5wcm90by5DYX'
    'JkUHJvZ3Jlc3NIAFIIcHJvZ3Jlc3MSNgoFcmVhZHkYAiABKAsyHi5kZWx1Z2UuZW5naW5lLnBy'
    'b3RvLkNhcmRSZWFkeUgAUgVyZWFkeRI2CgVlcnJvchgDIAEoCzIeLmRlbHVnZS5lbmdpbmUucH'
    'JvdG8uQ2FyZEVycm9ySABSBWVycm9yQgcKBXN0YXRl');

@$core.Deprecated('Use presetEntryDescriptor instead')
const PresetEntry$json = {
  '1': 'PresetEntry',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `PresetEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List presetEntryDescriptor = $convert.base64Decode(
    'CgtQcmVzZXRFbnRyeRISCgRwYXRoGAEgASgJUgRwYXRoEhIKBG5hbWUYAiABKAlSBG5hbWU=');

@$core.Deprecated('Use catalogDescriptor instead')
const Catalog$json = {
  '1': 'Catalog',
  '2': [
    {
      '1': 'synths',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PresetEntry',
      '10': 'synths'
    },
    {
      '1': 'kits',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PresetEntry',
      '10': 'kits'
    },
  ],
};

/// Descriptor for `Catalog`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List catalogDescriptor = $convert.base64Decode(
    'CgdDYXRhbG9nEjgKBnN5bnRocxgBIAMoCzIgLmRlbHVnZS5lbmdpbmUucHJvdG8uUHJlc2V0RW'
    '50cnlSBnN5bnRocxI0CgRraXRzGAIgAygLMiAuZGVsdWdlLmVuZ2luZS5wcm90by5QcmVzZXRF'
    'bnRyeVIEa2l0cw==');

@$core.Deprecated('Use paletteEntryDescriptor instead')
const PaletteEntry$json = {
  '1': 'PaletteEntry',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'weight', '3': 2, '4': 1, '5': 13, '10': 'weight'},
  ],
};

/// Descriptor for `PaletteEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paletteEntryDescriptor = $convert.base64Decode(
    'CgxQYWxldHRlRW50cnkSEgoEcGF0aBgBIAEoCVIEcGF0aBIWCgZ3ZWlnaHQYAiABKA1SBndlaW'
    'dodA==');

@$core.Deprecated('Use laneInfoDescriptor instead')
const LaneInfo$json = {
  '1': 'LaneInfo',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 13, '10': 'index'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'palette',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PaletteEntry',
      '10': 'palette'
    },
  ],
};

/// Descriptor for `LaneInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List laneInfoDescriptor = $convert.base64Decode(
    'CghMYW5lSW5mbxIUCgVpbmRleBgBIAEoDVIFaW5kZXgSEgoEbmFtZRgCIAEoCVIEbmFtZRI7Cg'
    'dwYWxldHRlGAMgAygLMiEuZGVsdWdlLmVuZ2luZS5wcm90by5QYWxldHRlRW50cnlSB3BhbGV0'
    'dGU=');

@$core.Deprecated('Use partInfoDescriptor instead')
const PartInfo$json = {
  '1': 'PartInfo',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 13, '10': 'index'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
    {
      '1': 'palette',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PaletteEntry',
      '10': 'palette'
    },
    {
      '1': 'lanes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.LaneInfo',
      '10': 'lanes'
    },
  ],
};

/// Descriptor for `PartInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List partInfoDescriptor = $convert.base64Decode(
    'CghQYXJ0SW5mbxIUCgVpbmRleBgBIAEoDVIFaW5kZXgSEgoEbmFtZRgCIAEoCVIEbmFtZRISCg'
    'Ryb2xlGAMgASgJUgRyb2xlEjsKB3BhbGV0dGUYBCADKAsyIS5kZWx1Z2UuZW5naW5lLnByb3Rv'
    'LlBhbGV0dGVFbnRyeVIHcGFsZXR0ZRIzCgVsYW5lcxgFIAMoCzIdLmRlbHVnZS5lbmdpbmUucH'
    'JvdG8uTGFuZUluZm9SBWxhbmVz');

@$core.Deprecated('Use genreInfoDescriptor instead')
const GenreInfo$json = {
  '1': 'GenreInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'parts',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PartInfo',
      '10': 'parts'
    },
  ],
};

/// Descriptor for `GenreInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List genreInfoDescriptor = $convert.base64Decode(
    'CglHZW5yZUluZm8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSMwoFcGFydH'
    'MYAyADKAsyHS5kZWx1Z2UuZW5naW5lLnByb3RvLlBhcnRJbmZvUgVwYXJ0cw==');

@$core.Deprecated('Use genresDescriptor instead')
const Genres$json = {
  '1': 'Genres',
  '2': [
    {
      '1': 'genres',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.GenreInfo',
      '10': 'genres'
    },
  ],
};

/// Descriptor for `Genres`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List genresDescriptor = $convert.base64Decode(
    'CgZHZW5yZXMSNgoGZ2VucmVzGAEgAygLMh4uZGVsdWdlLmVuZ2luZS5wcm90by5HZW5yZUluZm'
    '9SBmdlbnJlcw==');

@$core.Deprecated('Use bindingResultDescriptor instead')
const BindingResult$json = {
  '1': 'BindingResult',
  '2': [
    {'1': 'channel', '3': 1, '4': 1, '5': 13, '10': 'channel'},
    {'1': 'ok', '3': 2, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `BindingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bindingResultDescriptor = $convert.base64Decode(
    'Cg1CaW5kaW5nUmVzdWx0EhgKB2NoYW5uZWwYASABKA1SB2NoYW5uZWwSDgoCb2sYAiABKAhSAm'
    '9rEhQKBWVycm9yGAMgASgJUgVlcnJvcg==');

@$core.Deprecated('Use setupAppliedDescriptor instead')
const SetupApplied$json = {
  '1': 'SetupApplied',
  '2': [
    {
      '1': 'results',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.BindingResult',
      '10': 'results'
    },
  ],
};

/// Descriptor for `SetupApplied`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setupAppliedDescriptor = $convert.base64Decode(
    'CgxTZXR1cEFwcGxpZWQSPAoHcmVzdWx0cxgBIAMoCzIiLmRlbHVnZS5lbmdpbmUucHJvdG8uQm'
    'luZGluZ1Jlc3VsdFIHcmVzdWx0cw==');

@$core.Deprecated('Use midiActivityDescriptor instead')
const MidiActivity$json = {
  '1': 'MidiActivity',
  '2': [
    {'1': 'channel', '3': 1, '4': 1, '5': 13, '10': 'channel'},
  ],
};

/// Descriptor for `MidiActivity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List midiActivityDescriptor = $convert
    .base64Decode('CgxNaWRpQWN0aXZpdHkSGAoHY2hhbm5lbBgBIAEoDVIHY2hhbm5lbA==');

@$core.Deprecated('Use devicesDescriptor instead')
const Devices$json = {
  '1': 'Devices',
  '2': [
    {'1': 'audio_outputs', '3': 1, '4': 3, '5': 9, '10': 'audioOutputs'},
    {'1': 'midi_inputs', '3': 2, '4': 3, '5': 9, '10': 'midiInputs'},
  ],
};

/// Descriptor for `Devices`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devicesDescriptor = $convert.base64Decode(
    'CgdEZXZpY2VzEiMKDWF1ZGlvX291dHB1dHMYASADKAlSDGF1ZGlvT3V0cHV0cxIfCgttaWRpX2'
    'lucHV0cxgCIAMoCVIKbWlkaUlucHV0cw==');

@$core.Deprecated('Use freezeDescriptor instead')
const Freeze$json = {
  '1': 'Freeze',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'loaded', '3': 3, '4': 1, '5': 9, '10': 'loaded'},
  ],
};

/// Descriptor for `Freeze`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List freezeDescriptor = $convert.base64Decode(
    'CgZGcmVlemUSEgoEY29kZRgBIAEoCVIEY29kZRIYCgdtZXNzYWdlGAIgASgJUgdtZXNzYWdlEh'
    'YKBmxvYWRlZBgDIAEoCVIGbG9hZGVk');

@$core.Deprecated('Use errorReplyDescriptor instead')
const ErrorReply$json = {
  '1': 'ErrorReply',
  '2': [
    {'1': 'command', '3': 1, '4': 1, '5': 9, '10': 'command'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ErrorReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorReplyDescriptor = $convert.base64Decode(
    'CgpFcnJvclJlcGx5EhgKB2NvbW1hbmQYASABKAlSB2NvbW1hbmQSGAoHbWVzc2FnZRgCIAEoCV'
    'IHbWVzc2FnZQ==');

@$core.Deprecated('Use renderProgressDescriptor instead')
const RenderProgress$json = {
  '1': 'RenderProgress',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'done_s', '3': 2, '4': 1, '5': 1, '10': 'doneS'},
    {'1': 'total_s', '3': 3, '4': 1, '5': 1, '10': 'totalS'},
  ],
};

/// Descriptor for `RenderProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderProgressDescriptor = $convert.base64Decode(
    'Cg5SZW5kZXJQcm9ncmVzcxIOCgJpZBgBIAEoCVICaWQSFQoGZG9uZV9zGAIgASgBUgVkb25lUx'
    'IXCgd0b3RhbF9zGAMgASgBUgZ0b3RhbFM=');

@$core.Deprecated('Use sectionMarkerDescriptor instead')
const SectionMarker$json = {
  '1': 'SectionMarker',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'time_s', '3': 2, '4': 1, '5': 1, '10': 'timeS'},
  ],
};

/// Descriptor for `SectionMarker`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sectionMarkerDescriptor = $convert.base64Decode(
    'Cg1TZWN0aW9uTWFya2VyEhIKBG5hbWUYASABKAlSBG5hbWUSFQoGdGltZV9zGAIgASgBUgV0aW'
    '1lUw==');

@$core.Deprecated('Use peakPairDescriptor instead')
const PeakPair$json = {
  '1': 'PeakPair',
  '2': [
    {'1': 'min', '3': 1, '4': 1, '5': 2, '10': 'min'},
    {'1': 'max', '3': 2, '4': 1, '5': 2, '10': 'max'},
  ],
};

/// Descriptor for `PeakPair`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peakPairDescriptor = $convert.base64Decode(
    'CghQZWFrUGFpchIQCgNtaW4YASABKAJSA21pbhIQCgNtYXgYAiABKAJSA21heA==');

@$core.Deprecated('Use timelineNoteDescriptor instead')
const TimelineNote$json = {
  '1': 'TimelineNote',
  '2': [
    {'1': 'part', '3': 1, '4': 1, '5': 13, '9': 0, '10': 'part'},
    {'1': 'lane', '3': 2, '4': 1, '5': 13, '9': 0, '10': 'lane'},
    {'1': 'start_s', '3': 3, '4': 1, '5': 1, '10': 'startS'},
    {'1': 'length_s', '3': 4, '4': 1, '5': 1, '10': 'lengthS'},
    {'1': 'pitch', '3': 5, '4': 1, '5': 13, '10': 'pitch'},
    {'1': 'velocity', '3': 6, '4': 1, '5': 13, '10': 'velocity'},
  ],
  '8': [
    {'1': 'target'},
  ],
};

/// Descriptor for `TimelineNote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelineNoteDescriptor = $convert.base64Decode(
    'CgxUaW1lbGluZU5vdGUSFAoEcGFydBgBIAEoDUgAUgRwYXJ0EhQKBGxhbmUYAiABKA1IAFIEbG'
    'FuZRIXCgdzdGFydF9zGAMgASgBUgZzdGFydFMSGQoIbGVuZ3RoX3MYBCABKAFSB2xlbmd0aFMS'
    'FAoFcGl0Y2gYBSABKA1SBXBpdGNoEhoKCHZlbG9jaXR5GAYgASgNUgh2ZWxvY2l0eUIICgZ0YX'
    'JnZXQ=');

@$core.Deprecated('Use renderDoneDescriptor instead')
const RenderDone$json = {
  '1': 'RenderDone',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'wav_path', '3': 2, '4': 1, '5': 9, '10': 'wavPath'},
    {'1': 'duration_s', '3': 3, '4': 1, '5': 1, '10': 'durationS'},
    {
      '1': 'recipe',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.deluge.engine.proto.Recipe',
      '10': 'recipe'
    },
    {
      '1': 'sections',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.SectionMarker',
      '10': 'sections'
    },
    {
      '1': 'peaks',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.PeakPair',
      '10': 'peaks'
    },
    {
      '1': 'notes',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.deluge.engine.proto.TimelineNote',
      '10': 'notes'
    },
    {'1': 'warnings', '3': 8, '4': 3, '5': 9, '10': 'warnings'},
    {'1': 'peak_voices', '3': 9, '4': 1, '5': 13, '10': 'peakVoices'},
  ],
};

/// Descriptor for `RenderDone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderDoneDescriptor = $convert.base64Decode(
    'CgpSZW5kZXJEb25lEg4KAmlkGAEgASgJUgJpZBIZCgh3YXZfcGF0aBgCIAEoCVIHd2F2UGF0aB'
    'IdCgpkdXJhdGlvbl9zGAMgASgBUglkdXJhdGlvblMSMwoGcmVjaXBlGAQgASgLMhsuZGVsdWdl'
    'LmVuZ2luZS5wcm90by5SZWNpcGVSBnJlY2lwZRI+CghzZWN0aW9ucxgFIAMoCzIiLmRlbHVnZS'
    '5lbmdpbmUucHJvdG8uU2VjdGlvbk1hcmtlclIIc2VjdGlvbnMSMwoFcGVha3MYBiADKAsyHS5k'
    'ZWx1Z2UuZW5naW5lLnByb3RvLlBlYWtQYWlyUgVwZWFrcxI3CgVub3RlcxgHIAMoCzIhLmRlbH'
    'VnZS5lbmdpbmUucHJvdG8uVGltZWxpbmVOb3RlUgVub3RlcxIaCgh3YXJuaW5ncxgIIAMoCVII'
    'd2FybmluZ3MSHwoLcGVha192b2ljZXMYCSABKA1SCnBlYWtWb2ljZXM=');

@$core.Deprecated('Use renderFailedDescriptor instead')
const RenderFailed$json = {
  '1': 'RenderFailed',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
    {'1': 'freeze_code', '3': 3, '4': 1, '5': 9, '10': 'freezeCode'},
  ],
};

/// Descriptor for `RenderFailed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renderFailedDescriptor = $convert.base64Decode(
    'CgxSZW5kZXJGYWlsZWQSDgoCaWQYASABKAlSAmlkEhQKBWVycm9yGAIgASgJUgVlcnJvchIfCg'
    'tmcmVlemVfY29kZRgDIAEoCVIKZnJlZXplQ29kZQ==');

@$core.Deprecated('Use positionDescriptor instead')
const Position$json = {
  '1': 'Position',
  '2': [
    {'1': 'wav_path', '3': 1, '4': 1, '5': 9, '10': 'wavPath'},
    {'1': 'time_s', '3': 2, '4': 1, '5': 1, '10': 'timeS'},
  ],
};

/// Descriptor for `Position`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List positionDescriptor = $convert.base64Decode(
    'CghQb3NpdGlvbhIZCgh3YXZfcGF0aBgBIAEoCVIHd2F2UGF0aBIVCgZ0aW1lX3MYAiABKAFSBX'
    'RpbWVT');
