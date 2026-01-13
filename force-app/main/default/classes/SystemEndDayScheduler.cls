global class SystemEndDayScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        SystemEndDayController.autoEndDailyLogs();
    }
}