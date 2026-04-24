// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comic_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComicChapterAdapter extends TypeAdapter<ComicChapter> {
  @override
  final int typeId = 1;

  @override
  ComicChapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicChapter(
      id: fields[0] as String,
      seriesKey: fields[1] as String,
      seriesTitle: fields[2] as String,
      chapterTitle: fields[3] as String,
      originalFilename: fields[4] as String,
      sourceRelativePath: fields[5] as String,
      format: fields[6] as ComicFormat,
      importedAt: fields[7] as DateTime,
      modifiedAt: fields[8] as DateTime?,
      issueNumber: fields[9] as double?,
      pageCount: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ComicChapter obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.seriesKey)
      ..writeByte(2)
      ..write(obj.seriesTitle)
      ..writeByte(3)
      ..write(obj.chapterTitle)
      ..writeByte(4)
      ..write(obj.originalFilename)
      ..writeByte(5)
      ..write(obj.sourceRelativePath)
      ..writeByte(6)
      ..write(obj.format)
      ..writeByte(7)
      ..write(obj.importedAt)
      ..writeByte(8)
      ..write(obj.modifiedAt)
      ..writeByte(9)
      ..write(obj.issueNumber)
      ..writeByte(10)
      ..write(obj.pageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicChapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicProgressAdapter extends TypeAdapter<ComicProgress> {
  @override
  final int typeId = 2;

  @override
  ComicProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicProgress(
      pageIndex: fields[0] as int,
      lastReadAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ComicProgress obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.pageIndex)
      ..writeByte(1)
      ..write(obj.lastReadAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicFormatAdapter extends TypeAdapter<ComicFormat> {
  @override
  final int typeId = 0;

  @override
  ComicFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ComicFormat.cbz;
      case 1:
        return ComicFormat.zip;
      case 2:
        return ComicFormat.cbr;
      case 3:
        return ComicFormat.rar;
      case 4:
        return ComicFormat.pdf;
      case 5:
        return ComicFormat.folder;
      case 6:
        return ComicFormat.image;
      default:
        return ComicFormat.cbz;
    }
  }

  @override
  void write(BinaryWriter writer, ComicFormat obj) {
    switch (obj) {
      case ComicFormat.cbz:
        writer.writeByte(0);
        break;
      case ComicFormat.zip:
        writer.writeByte(1);
        break;
      case ComicFormat.cbr:
        writer.writeByte(2);
        break;
      case ComicFormat.rar:
        writer.writeByte(3);
        break;
      case ComicFormat.pdf:
        writer.writeByte(4);
        break;
      case ComicFormat.folder:
        writer.writeByte(5);
        break;
      case ComicFormat.image:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
