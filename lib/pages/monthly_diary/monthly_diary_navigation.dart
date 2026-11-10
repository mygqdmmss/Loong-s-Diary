import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:moodiary/pages/diary_details/diary_details_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

Future<void> openMonthlyDiary(Diary diary) async {
  Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
  await Get.toNamed(AppRoutes.diaryPage, arguments: [diary.clone(), true]);
  final latest = await IsarUtil.getDiaryByID(diary.isarId);
  // Older memories need not be in a paginated home list. Refresh the affected
  // lists instead of replacing an index, and leave category selection alone.
  final tags = <String>{
    'default',
    if (diary.categoryId != null) diary.categoryId!,
    if (latest?.categoryId != null) latest!.categoryId!,
  };
  for (final tag in tags) {
    if (Bind.isRegistered<DiaryTabViewLogic>(tag: tag)) {
      await Bind.find<DiaryTabViewLogic>(tag: tag).updateDiary();
    }
  }
}
