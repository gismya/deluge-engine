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

import 'package:protobuf/protobuf.dart' as $pb;

/// Single source of truth for the protocol version checked in Hello (spec §7.2).
/// v1 requires an exact match; raise this when adding a new message kind (spec §7.6).
class ProtocolVersion extends $pb.ProtobufEnum {
  static const ProtocolVersion PROTOCOL_VERSION_UNSPECIFIED = ProtocolVersion._(
      0, _omitEnumNames ? '' : 'PROTOCOL_VERSION_UNSPECIFIED');
  static const ProtocolVersion PROTOCOL_VERSION_CURRENT =
      ProtocolVersion._(1, _omitEnumNames ? '' : 'PROTOCOL_VERSION_CURRENT');

  static const $core.List<ProtocolVersion> values = <ProtocolVersion>[
    PROTOCOL_VERSION_UNSPECIFIED,
    PROTOCOL_VERSION_CURRENT,
  ];

  static final $core.List<ProtocolVersion?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ProtocolVersion? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProtocolVersion._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
