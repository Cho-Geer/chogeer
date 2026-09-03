/**
 * @description F-26 写回用投影 Upsert の system context 実行ヘルパー（P0-3・S-4 登記②解消 2026-09-03）
 * 設計出典：DD-02 §3.1（Upsert・部分成功許容）・F-32 表後注記（Queueable system context と同枠）・
 * ユーザー拍板 Option 1（写回＝内部システム操作・明示 system context）。
 *
 * 目的：S-3 BookingProjectionRest（with sharing＝user mode）の upsert は、F-32 凍結値で
 * Booking__c を Read のみ持つ Site ユーザーが enqueue する F-26 写回経路では、
 * INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY で必ず失敗する（2026-09-03 実測・
 * AccessLevel.SYSTEM_MODE 単独では回避不可）。本ヘルパーを without sharing（明示 system context）とし、
 * 写回の upsert だけを system 実行して F-26 写回を成立させる。
 *
 * セキュリティスコープ：
 * - 呼出元は BookingProjectionRest.receiveProjection（投影入口）のみ。他用途への転用禁止
 *   （汎用 DML ヘルパー・Site ユーザー操作の代理等には使わない）。
 * - without sharing のため、本クラスを経由した DML は行級/CRUD/FLS を強制しない。
 *   内部システム操作専用の明示 system context であり、Site ユーザーの権限を拡大するものではない
 *   （呼出元のクエリ＝FOR UPDATE 等は S-3 側の with sharing のまま維持される）。
 */
global without sharing class BookingProjectionDmlHelper {
  /**
   * @description 投影 Upsert を system context で実行（S-3 委譲専用・BookingExternalId__c で Upsert・
   * 部分成功許容 false）
   * @param record 投影レコード（buildProjectionRecord の成果物・Account__c は含まない）
   * @return 単一 UpsertResult（成功時は record Id・失敗時は errors を保持）
   */
  global static Database.UpsertResult upsertProjection(Booking__c record) {
    return Database.upsert(
      new List<Booking__c>{ record },
      Booking__c.BookingExternalId__c,
      false,
      AccessLevel.SYSTEM_MODE
    )[0];
  }
}
