# Work History

## 2026-03-26

### Stockpile Filter (Allow/Deny)
- `StockpileZone`에 필터 모드(`All`, `AllowOnly`, `DenyList`)와 자원별 필터 목록을 추가했다.
- `accepts_resource()`를 도입하고 운반 대상 구역 선택 시 필터를 통과한 구역만 후보로 사용하도록 연결했다.
- HUD 좌측에 `Stockpile Filter` UI를 추가해 선택된 저장구역의 필터 모드/자원 체크를 수정할 수 있게 했다.

### Haul Reservation Hardening
- `JobSystem`에 `reserved_drop_ids`를 추가해 `job_queued`와 함께 이중 예약 보호를 적용했다.
- 동일 드랍 중복 큐잉을 막는 검사(`_has_queued_haul_job`)를 추가했다.
- 예약 정리(`_cleanup_haul_reservations`)와 수동 해제(`release_haul_reservation`) 경로를 추가했다.
- 주민의 운반 취소/완료 시 `haul_job_released` 신호를 통해 예약이 해제되도록 연결했다.

### Haul Priority Tuning
- 운반 job 점수 계산에 거리, 재고 부족(`urgency`), 드랍량(`drop_amount`) 가중치를 반영했다.
- 재고 목표(`target_stock`)와 현재 재고(`resource_stock`) 차이를 기반으로 긴급도를 계산해 운반 job에 기록했다.

### Workbench Recipe Restriction UI
- 작업대 선택 UI를 제작 컨트롤 영역에 추가하고, 선택 작업대 기준으로 레시피 목록을 필터링하도록 변경했다.
- 제작 큐 payload를 `recipe_id` 단일 값에서 `{recipe_id, workstation_id}` 구조로 확장했다.
- 작업대별 실제 위치 맵을 만들어 해당 작업대로만 제작 작업이 생성되도록 조정했다.

### Autopilot Next Item (Craft Queue Control)
- 자동 확장 항목으로 `제작 대기열 취소/재정렬`을 선택했다.
- `Queue Front`, `Dequeue`, `Clear` 컨트롤을 추가해 앞삽입/앞삭제/전체삭제를 지원했다.
- `JobSystem`에 `enqueue_craft_recipe_front`, `dequeue_craft_recipe`, `clear_craft_queue`를 추가했다.

### Validation
- Godot headless verbose 부팅 검증을 수행했고 스크립트 파싱 오류를 수정했다.
- 최종 검증에서 신규 변경 스크립트 로딩 및 실행 루프가 정상 동작함을 확인했다.

### Continue: Haul Lock Timeout/Reassign
- 자동 진행의 다음 단계로 운반 락 타임아웃/재할당 안정화를 추가했다.
- `JobSystem`에 다음 정책을 적용했다.
  - 큐 상태 haul job 타임아웃(`HAUL_QUEUE_TIMEOUT_MS`) 초과 시 예약/잡 해제
  - 배정 상태 haul job 타임아웃(`HAUL_ASSIGN_TIMEOUT_MS`) 초과 시 주민 작업 취소 후 재큐 가능 상태로 복구
  - 예약 테이블을 `assigned_to + reserved_at_ms` 구조로 관리
- 목적: 경로 막힘/실패로 인한 드랍 영구 예약 고착을 줄이고 자동 운반 루프 복원력 강화.

### Continue: Zone Priority and Per-Resource Limit
- 저장구역에 `zone_priority`와 자원별 `resource_limits`(기본 `-1` 무제한)를 추가했다.
- 운반 대상 구역 선택 시 필터 + 수용 가능량 + 우선순위를 함께 고려하도록 `JobSystem`의 구역 선택 점수를 확장했다.
- 운반 완료 시 전량 강제 반영 대신, 저장구역 수용 가능량만큼만 반입하고 남는 자원은 드랍으로 유지되도록 수정했다.
- HUD에 저장구역 고급 설정 UI를 추가했다.
  - 구역 우선순위(Spin)
  - 자원별 제한(자원 선택 + 제한값 + Apply)
