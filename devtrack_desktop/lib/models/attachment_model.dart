import 'dart:convert';
import 'dart:typed_data';

class AttachmentModel {
  final int id;
  final int issueId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? fileData;
  final int uploaderId;
  final String uploaderName;
  final String createdAt;

  AttachmentModel({
    required this.id,
    required this.issueId,
    required this.fileName,
    this.fileType = '',
    this.fileSize = 0,
    this.fileData,
    this.uploaderId = 0,
    this.uploaderName = '',
    this.createdAt = '',
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] ?? 0,
      issueId: json['issueId'] ?? 0,
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      fileData: json['fileData'],
      uploaderId: json['uploaderId'] ?? 0,
      uploaderName: json['uploaderName'] ?? '',
      createdAt: _formatTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issueId': issueId,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'fileData': fileData,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'createdAt': createdAt,
    };
  }

  bool get isImage {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        fileType.startsWith('image/');
  }

  bool get isVideo {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        fileType.startsWith('video/');
  }

  bool get isPdf {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') || fileType.contains('pdf');
  }

  Uint8List? get bytes {
    if (fileData == null || fileData!.isEmpty) return null;
    try {
      return base64Decode(fileData!);
    } catch (_) {
      return null;
    }
  }

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    final text = value.toString().replaceAll('T', ' ');
    return text.length > 16 ? text.substring(0, 16) : text;
  }
}
