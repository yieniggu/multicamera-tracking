// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CameraModelAdapter extends TypeAdapter<CameraModel> {
  @override
  final int typeId = 0;

  @override
  CameraModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CameraModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      rtspUrl: fields[3] as String,
      thumbnailUrl: fields[4] as String?,
      projectId: fields[5] as String,
      groupId: fields[6] as String,
      userRoles: (fields[7] as Map).cast<String, String>(),
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CameraModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.rtspUrl)
      ..writeByte(4)
      ..write(obj.thumbnailUrl)
      ..writeByte(5)
      ..write(obj.projectId)
      ..writeByte(6)
      ..write(obj.groupId)
      ..writeByte(7)
      ..write(obj.userRoles)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
