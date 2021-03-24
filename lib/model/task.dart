class Task {
  Task({
    this.id,
    this.ownerId,
    this.description,
    this.detail,
    this.startDate,
    this.dueDate,
    this.complete,
    this.priority,
  });

  final String id;
  final String ownerId;
  final String description;
  final String detail;
  final DateTime startDate;
  final DateTime dueDate;
  final int complete; // 0 to 100
  final int priority; // 0 to 5
}
