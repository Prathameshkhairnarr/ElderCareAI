class TaskModel {
  final int id;
  final int guardianId;
  final int elderId;
  final String title;
  final String taskType;
  final String? description;
  final String iconKey;
  final DateTime? scheduledTime;
  final String recurrence;
  final String status;
  final String priority;
  final DateTime? completedAt;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.guardianId,
    required this.elderId,
    required this.title,
    required this.taskType,
    this.description,
    required this.iconKey,
    this.scheduledTime,
    required this.recurrence,
    required this.status,
    required this.priority,
    this.completedAt,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      guardianId: json['guardian_id'],
      elderId: json['elder_id'],
      title: json['title'],
      taskType: json['task_type'],
      description: json['description'],
      iconKey: json['icon_key'],
      scheduledTime: json['scheduled_time'] != null ? DateTime.parse(json['scheduled_time']) : null,
      recurrence: json['recurrence'],
      status: json['status'],
      priority: json['priority'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guardian_id': guardianId,
      'elder_id': elderId,
      'title': title,
      'task_type': taskType,
      'description': description,
      'icon_key': iconKey,
      'scheduled_time': scheduledTime?.toIso8601String(),
      'recurrence': recurrence,
      'status': status,
      'priority': priority,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
