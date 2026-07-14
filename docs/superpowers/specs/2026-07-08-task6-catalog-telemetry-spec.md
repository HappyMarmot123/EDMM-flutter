# Task 6: Catalog Fallback/Observability Spec

작성일: 2026-07-08
범위: catalog 검색/목록 로딩 실패 정합성, 재시도, stale fallback

## Event contract (hardening seam)

- 파일: `lib/domain/telemetry/catalog_search_telemetry.dart`
- 연결점: `CatalogSearchViewModel` 생성자 `telemetry` 주입점

| Event name | Trigger | Payload keys |
| --- | --- | --- |
| `catalog_load_requested` | `CatalogSearchViewModel._loadCurrent()` 진입 | `view`, `query_length`, `is_retry`, `force_refresh` |
| `catalog_load_succeeded` | 조회 성공 | `view`, `query_length`, `result_count`, `has_results` |
| `catalog_load_failed` | 조회 실패 | `view`, `query_length`, `failure_category`, `failure_retryable`, `failure_status_code`(optional), `error_state`, `stale_fallback` |
| `catalog_load_retry_requested` | `retry()` 호출 시 | `view`, `query_length`, `is_retry=true`, `force_refresh=true` |
| `catalog_load_stale_fallback_used` | 실패 시 이전 성공 목록이 존재해서 목록 유지했을 때 | `view`, `query_length`, `stale_fallback=true`, `result_count` |

### 분류 규칙

- `failure_category`:
  - `network` = `NetworkFailure`
  - `server` = `ServerFailure`
  - `parse` = `ParseFailure`
  - `unknown` = 기타

- `failure_retryable`:
  - `network` → `true`
  - `server` → `true` if status is `408`, `429`, or `>= 500`; else `false`
  - 기타 → `false`

- `error_state`:
  - `error_with_stale`: 실패했지만 동일 view의 이전 성공 목록이 존재해 `tracks` 유지
  - `error_without_stale`: 실패했을 때 이전 성공 목록이 없어 빈 화면 유지

### 보안/개인정보 규칙

- raw query 문자열 자체는 이벤트 payload에 넣지 않음.
- 오직 `query_length`만 전송.
- 실패 객체의 상세 문자열은 전달하지 않음(재시도 정책/카테고리/상태코드만 전달).

## 테스트 포인트

- `test/ui/catalog_search/catalog_search_view_model_test.dart`
  - 실패 시 `error_with_stale` 상태 + `stale_fallback` 이벤트
  - `retry()` 시 retry 이벤트 쌍 발행
  - `ServerFailure(404)`은 `failure_category=server`, `failure_retryable=false`
