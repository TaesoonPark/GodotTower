## 1회차

### 구현 기능
- 연구 보너스 타입 확장: `BuildWorkSpeed`, `RepairWorkSpeed`, `HaulUrgencyBoost`, `RestRecoverBoost` 추가.
- 레이드 보상 스케일링: 웨이브 종류/진행 시간 반영해 보상량 증가.
- 적 처치 드롭: `Raider`/`Zombie` 사망 시 전리품 드롭.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/data/ResearchDef.gd` (사용 타입 확장 반영)
- `data/research/engineering_1.tres`
- `data/research/logistics_1.tres`
- `data/research/comfort_1.tres`
- `data/research/defense_theory_1.tres`

### 핵심 로직 포인트
- 연구 보상 적용 분기(`_apply_research_bonus`)에 신규 타입 추가.
- `_grant_raid_reward`에서 `_raid_wave_kind`, `_elapsed_game_seconds` 기반 스케일 계산.
- `Zombie` 사망 시그널 연결 및 `Raider`/`Zombie` 사망 핸들러에서 자원 드롭 생성.

### 검증 결과
- 린트 오류 없음.
- 연구 완료 후 보너스 값이 런타임 파라미터에 반영되는 구조 확인.
- 레이드 종료/적 처치 시 드롭 생성 경로 확인.

### 남은 리스크
- 처치 드롭 밸런스(초반 자원 과잉)는 플레이테스트 조정 필요.

---

## 2회차

### 구현 기능
- 구조물 자동 수리 정책: 임계치(기본 75%) 이하만 수리 요청.
- 함정 유지보수 루프: 소모된 함정 충전을 위한 `MaintainTrap` 작업 추가.
- 방어 상태 표시: HUD 상단에 수리/함정정비 상태 텍스트 표시.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/systems/JobSystem.gd`
- `scripts/core/Colonist.gd`
- `scripts/core/HUDController.gd`
- `scripts/core/BuildingSite.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/data/JobPriorityData.gd`

### 핵심 로직 포인트
- `JobSystem`에 `queue_trap_maint_job`, `request_trap_maintenance_jobs` 추가.
- `Colonist`에 `MaintainTrap` 작업 실행/완료 루틴 추가.
- 함정 메타(`trap_max_charges`, `trap_maint_job_queued`) 추가 및 함정 탄약 0일 때 발동 중지.

### 검증 결과
- 린트 오류 없음.
- 함정 소모 후 유지보수 작업 큐잉/완료 경로 존재 확인.
- HUD `방어 상태` 텍스트 갱신 호출 확인.

### 남은 리스크
- 함정 유지보수 자원 소모를 아직 강제하지 않아 운영 난이도는 낮은 편.

---

## 3회차

### 구현 기능
- 작업대별 제작 큐 일시정지/재개.
- 식량 위기 기반 운반 긴급도 자동 부스트.
- 스톡파일 프리셋(전체/식량/전투물자) 적용.

### 수정 파일
- `scripts/systems/JobSystem.gd`
- `scripts/core/HUDController.gd`
- `scripts/core/MainController.gd`
- `scripts/core/StockpileZone.gd`

### 핵심 로직 포인트
- `JobSystem`에 `set_craft_queue_paused`, `is_craft_queue_paused` 추가.
- `request_craft_jobs`에서 작업대 pause 상태면 큐 처리 스킵.
- `set_haul_urgency_multiplier` 도입 후 평균 배고픔 기반 가중치 적용.
- Stockpile에 `apply_preset` 추가, HUD 프리셋 UI와 연결.

### 검증 결과
- 린트 오류 없음.
- 작업대 pause 상태에서 신규 제작 잡 생성 차단 경로 확인.
- 프리셋 적용 시 필터/우선순위 변경 반영 확인.

### 남은 리스크
- 프리셋 종류가 고정 3개라 후속 확장(사용자 정의 저장)은 미구현.

---

## 4회차

### 구현 기능
- 주야 보정: 이동/명중 보너스(낮 유리, 밤 불리) 적용.
- 무드/휴식 기반 작업 효율 연동.
- 침대 업그레이드 동등 루프: `RestRecoverBoost` 연구 보너스로 휴식 회복 강화.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/Colonist.gd`
- `scripts/core/Raider.gd`
- `scripts/core/Zombie.gd`
- `data/research/comfort_1.tres`

### 핵심 로직 포인트
- `MainController`에서 주야 판정 후 아군/적군 외부 이동/명중 보정치 전파.
- `Colonist._condition_work_speed_multiplier()`로 무드/휴식이 작업속도에 곱연산.
- 연구 보너스로 `rest_recover_multiplier` 추가 가중.

### 검증 결과
- 린트 오류 없음.
- 작업 진행 속도가 무드/휴식에 따라 달라지는 경로 확인.
- 주야 보정 값이 아군/적군 외부 파라미터에 반영되는 구조 확인.

### 남은 리스크
- 주야 보정 수치 체감 강도는 플레이테스트로 튜닝 필요.

---

## 5회차

### 구현 기능
- 농장 비옥도 배율 시스템.
- 작물 로테이션(연속 재배에 따른 성장 시간 변화).
- 전술 버프 건물 `CommandPost` 및 범위 내 명중 보정.

### 수정 파일
- `scripts/core/FarmZone.gd`
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`
- `scripts/core/Colonist.gd`
- `data/buildings/command_post.tres`

### 핵심 로직 포인트
- `FarmZone`에 `zone_fertility`, `rotation_mult`, `last_crop`, `consecutive_crop` 도입.
- 성장 완료 판정에 비옥도/로테이션 배율 반영.
- `BuildingDef`/메타에 `command_aura_bonus`, `command_aura_range` 추가.
- `Colonist` 전투 계산 시 근처 지휘 건물 오라 보너스 합산.

### 검증 결과
- 린트 오류 없음.
- 농장 라벨에 비옥도 표시 및 성장 계산 반영 경로 확인.
- `CommandPost` 배치 시 `command_structures` 그룹/메타 전파 확인.

### 남은 리스크
- 로테이션 공식이 단순 선형이라 작물별 고유 특성은 미반영.

---

## 전체 5회차 총평
- 기존 아키텍처(`MainController` 오케스트레이션 + `JobSystem` 큐 + `Colonist` 실행 + `HUDController` 입력/UI) 위에서 신규 시스템을 증분 적용.
- 경제/전투/농업/방어/운영성 기능이 각각 연결되어 게임 루프 밀도 증가.
- 성능 측면에서 기존 경로 LOD/시그니처 기반 갱신 정책과 충돌하지 않도록 작업 요청/갱신 빈도는 보수적으로 유지.

## 다음 확장 후보 3개
- 함정 정비에 자원 운반(실제 재료 소모) 단계 추가.
- 스톡파일 프리셋 사용자 저장/불러오기.
- 주야/날씨 연계 이벤트(야간 레이드 특수 페이즈, 시야/명중 보정 분화).

---

## 6회차 (2차 반복 1)

### 구현 기능
- 연구 보너스 확장: `TrapDamageBoost`, `RaidRewardBoost` 타입 추가.
- 레이드 보상/처치 드롭 확장: 연구 보정 기반 보상량 증가 및 희귀 드롭(강철/활) 추가.
- 후반 방어 빌드 확장: `WatchTower` 건물 추가 및 `DefenseTheoryI` 해금 목록 연동.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`
- `data/research/trap_engineering_1.tres`
- `data/research/salvage_1.tres`
- `data/research/defense_theory_1.tres`
- `data/buildings/watch_tower.tres`
- `data/buildings/command_post.tres`

### 핵심 로직 포인트
- `_apply_research_bonus`에 신규 보너스 타입 분기 추가.
- `_grant_raid_reward`에 연구 기반 승수 반영.
- 사망 이벤트 드롭 테이블에 확률 드롭 분기 추가.

### 검증 결과
- 린트 점검 대상 스크립트에서 오류 없음.
- 신규 연구/건물 정의 파일 로딩 경로 확인.

---

## 7회차 (2차 반복 2)

### 구현 기능
- 함정 정비 재료 소모: `MaintainTrap` 완료 시 `Wood 1 + Steel 1` 필수 소모.
- 야간 자동수리 보수화: 밤에는 자동수리 임계치 하향 적용(중파 우선).
- 방어 상태 HUD 고도화: 소진 함정 수와 정비 재료 상태(가능/부족) 표시.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/Colonist.gd`

### 핵심 로직 포인트
- `try_consume_trap_maintenance_cost()`로 자원 검증 후 일괄 소모.
- `Colonist._complete_maintain_trap_job()`에서 재료 부족 시 충전 중단.
- `_get_maintainable_traps()` 상태 문자열에 소진 함정/재료 상태 반영.

### 검증 결과
- 정비 재료 부족 시 함정 충전 완료가 차단되는 경로 확인.
- 방어 상태 텍스트가 추가 상태값을 포함하도록 갱신됨.

---

## 8회차 (2차 반복 3)

### 구현 기능
- 제작 큐 앞삽입 UI 활성화: `앞에 추가` 버튼을 HUD에 노출.
- 작업대 큐 앞삽입 처리: 메인 컨트롤러에서 `enqueue_craft_recipe_front()` 연결.
- 스톡파일 프리셋 확장: `Build(건설 자재)` 프리셋 추가.

### 수정 파일
- `scripts/core/HUDController.gd`
- `scripts/core/MainController.gd`
- `scripts/core/StockpileZone.gd`

### 핵심 로직 포인트
- HUD 신규 시그널 `craft_recipe_front_queued` 추가.
- `_on_craft_recipe_front_queued` 핸들러로 작업대별 큐 앞삽입 반영.
- `StockpileZone.apply_preset()`에 건설 자재 필터 세트 추가.

### 검증 결과
- 일반 큐잉/앞삽입 큐잉 두 경로가 모두 동작하도록 연결 확인.
- Build 프리셋 선택 시 필터 타입/우선순위가 반영됨.

---

## 9회차 (2차 반복 4)

### 구현 기능
- 주야 기반 needs 소모율 조정(야간 완화/주간 표준화).
- 배정 침대 + 야간 시 휴식 회복 보너스 추가.
- `Comfort II` 연구 추가로 휴식 회복 상한 확장.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/Colonist.gd`
- `data/research/comfort_2.tres`

### 핵심 로직 포인트
- `Colonist`에 `need_decay_multiplier`/setter 추가 후 `tick_needs`에 반영.
- `_apply_passive_item_bonuses`에서 시간대 기반 needs/recover 계수 전파.
- 기존 `RestRecoverBoost` 타입 재사용으로 단계형 휴식 연구 추가.

### 검증 결과
- needs tick 연산에 외부 계수가 적용되는 경로 확인.
- 야간/침대 배정 시 회복 계수가 추가로 가중되는 구조 확인.

---

## 10회차 (2차 반복 5)

### 구현 기능
- 지휘 오라 확장: 명중뿐 아니라 방어 오라도 적용.
- 사기(무드) 기반 방어 보정 추가.
- 농장 토양 회복/피로도: 유휴 비율이 높으면 비옥도 회복, 과밀 재배 시 저하.

### 수정 파일
- `scripts/core/Colonist.gd`
- `scripts/core/FarmZone.gd`
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`
- `data/buildings/command_post.tres`
- `data/buildings/watch_tower.tres`

### 핵심 로직 포인트
- `command_aura_defense_bonus` 메타를 건물 정의/배치/완공 전파 경로에 추가.
- `get_combat_defender_profile()`에 지휘 방어 오라 + 무드 보정 합산.
- `FarmZone.tick_growth()`에서 플롯 점유율 기반 비옥도 드리프트 적용.

### 검증 결과
- command 구조물에서 방어 오라 메타 전달 및 계산 경로 확인.
- 농장 비옥도 값이 재배 밀도에 따라 동적으로 변하도록 반영됨.

---

## 11회차 (3차 반복 1)

### 구현 기능
- 연구 보너스 타입 확장: `TrapRangeBoost`, `EnemyDropBoost` 추가.
- 함정 교전 반경 강화: 연구 완료 시 함정 타겟 탐지 거리 증가.
- 신규 방어 건물 `SignalFire` 추가(지휘 명중/이동 오라).

### 수정 파일
- `scripts/core/MainController.gd`
- `data/research/trap_range_1.tres`
- `data/research/scavenging_1.tres`
- `data/buildings/signal_fire.tres`
- `data/research/battle_drill_1.tres`

### 핵심 로직 포인트
- `_apply_research_bonus()`에 두 신규 보너스 타입 분기 추가.
- `_update_defense_traps()`의 타겟 거리 상한을 연구 배율로 확장.
- 적 사망 드롭 확률에 연구 배율을 반영해 희귀 드롭 체감 강화.

### 검증 결과
- 연구 로드/적용 경로에서 신규 보너스 타입 분기 확인.
- 함정 타겟 거리 계산에 연구 배율 반영 확인.

---

## 12회차 (3차 반복 2)

### 구현 기능
- 함정 정비 재료 소모를 충전량 기반으로 스케일링(부족 탄약 많을수록 소모 증가).
- 자동 수리 정책 세분화: 벽/문은 더 높은 수리 임계치로 우선 관리.
- 방어 상태 텍스트에 예상 정비 재료량 표시.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/Colonist.gd`

### 핵심 로직 포인트
- `try_consume_trap_maintenance_cost(batch_count)`로 배치 소모 지원.
- `Colonist._complete_maintain_trap_job()`에서 누락 충전량 기준 배치 계산.
- `_get_maintainable_traps()`에서 총 누락 충전량 기반 예상 비용 산출.

### 검증 결과
- 함정 충전량이 클수록 정비 자원 소모가 증가하는 경로 확인.
- 벽/문의 자동수리 선별이 일반 구조물보다 앞서 적용되는 조건 확인.

---

## 13회차 (3차 반복 3)

### 구현 기능
- 스톡파일 프리셋 `Industry` 추가(제작 핵심 자재/무기 집중).
- 식민지 핵심 자재 부족 시 운반 긴급도 자동 부스트.
- 지휘 건물 이동 오라 메타(`command_aura_move_bonus`) 파이프라인 추가.

### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/StockpileZone.gd`
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`

### 핵심 로직 포인트
- HUD 프리셋 목록에 `Industry` 노출 후 Stockpile preset 매핑 확장.
- `_haul_urgency_multiplier_by_colony_state()`에 자재 부족 가중치 추가.
- 건물 정의/배치/완공 메타 전달에 이동 오라 필드 연동.

### 검증 결과
- 프리셋 적용 시 산업 자재 필터가 반영되는 경로 확인.
- command 구조물의 이동 오라 메타가 실체 노드까지 전파됨.

---

## 14회차 (3차 반복 4)

### 구현 기능
- 주야 보정을 이산(낮/밤)에서 연속 보간(새벽/황혼 포함)으로 변경.
- 전투 복장 모드에서 needs 소모율 상승(긴장 상태 페널티).
- 전술 연구 `Discipline I` 추가 및 `DrillYard` 해금.

### 수정 파일
- `scripts/core/MainController.gd`
- `data/research/discipline_1.tres`
- `data/buildings/drill_yard.tres`

### 핵심 로직 포인트
- `_day_night_lerp()` 도입 후 이동/명중 보정값을 `lerpf`로 계산.
- `_apply_day_night_to_enemies()`도 동일 보간 로직으로 통일.
- `_apply_passive_item_bonuses()`에서 복장 모드에 따라 need decay 추가 가중.

### 검증 결과
- 시간 경과에 따라 이동/명중 보정이 부드럽게 변하는 계산 경로 확인.
- 전투 모드 전환 시 needs 계수 변화 경로 확인.

---

## 15회차 (3차 반복 5)

### 구현 기능
- 지휘 이동 오라 실제 적용: 식민지 이동 속도에 지휘 건물 오라 가중.
- 농장 수확량에 비옥도 반영(고비옥 +, 저비옥 -).
- `CommandPost`/`WatchTower`에 이동 오라 수치 추가.

### 수정 파일
- `scripts/core/Colonist.gd`
- `scripts/core/FarmZone.gd`
- `data/buildings/command_post.tres`
- `data/buildings/watch_tower.tres`

### 핵심 로직 포인트
- `_nearby_command_move_multiplier()` 추가 후 `_process_movement()` 속도 계산에 반영.
- `FarmZone.harvest_crop()`에서 비옥도 기반 수확량 배율 계산.
- 기존 전술 건물 정의에 이동 오라 값 부여로 즉시 체감 가능하게 구성.

### 검증 결과
- 이동 처리 루틴에 command 오라 배율이 합성되는 경로 확인.
- 수확량 반환값이 비옥도에 따라 동적으로 변하도록 반영됨.

---

## 16회차 (4차 반복 1)
### 구현 기능
- 연구 보너스 `TrapCooldownBoost` 추가.
- 연구 보너스 `FarmYieldBoost` 추가.
- 연구 보너스 `FarmResilienceBoost` 추가.
### 수정 파일
- `scripts/core/MainController.gd`
- `data/research/trap_mechanics_1.tres`
- `data/research/agronomy_2.tres`
- `data/research/soil_science_1.tres`

## 17회차 (4차 반복 2)
### 구현 기능
- 연구 보너스 `EnemyNightSlow` 추가.
- 함정 쿨다운 계산에 연구 승수 적용.
- 야간 적 이동에 연구 기반 감속 적용.
### 수정 파일
- `scripts/core/MainController.gd`
- `data/research/moonlight_patrol_1.tres`

## 18회차 (4차 반복 3)
### 구현 기능
- `FarmZone`에 수확 배율(`yield_multiplier`) 추가.
- `FarmZone`에 비옥도 안정도(`fertility_resilience`) 추가.
- `MainController`에서 농장 존에 신규 계수 전파.
### 수정 파일
- `scripts/core/FarmZone.gd`
- `scripts/core/MainController.gd`

## 19회차 (4차 반복 4)
### 구현 기능
- 건물 메타에 `farm_growth_bonus` 추가.
- 건물 메타에 `farm_yield_bonus` 추가.
- 건물 메타에 `farm_support_range` 추가.
### 수정 파일
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`

## 20회차 (4차 반복 5)
### 구현 기능
- 농장 지원 구조물 그룹(`farm_support_structures`) 연동.
- 농장 성장 계산에 주변 지원 성장 보너스 반영.
- 농장 수확 계산에 주변 지원 수확 보너스 반영.
### 수정 파일
- `scripts/core/FarmZone.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`

---

## 21회차 (5차 반복 1)
### 구현 기능
- 신규 건물 `Granary` 추가.
- 신규 건물 `IrrigationPump` 추가.
- 신규 건물 `Greenhouse` 추가.
### 수정 파일
- `data/buildings/granary.tres`
- `data/buildings/irrigation_pump.tres`
- `data/buildings/greenhouse.tres`

## 22회차 (5차 반복 2)
### 구현 기능
- 신규 건물 `LanternTower` 추가.
- 신규 건물 `TrapController` 추가.
- 신규 건물 `SupplyDepot` 추가.
### 수정 파일
- `data/buildings/lantern_tower.tres`
- `data/buildings/trap_controller.tres`
- `data/buildings/supply_depot.tres`

## 23회차 (5차 반복 3)
### 구현 기능
- `Agronomy II` 연구 추가(`FarmYieldBoost`).
- `Agronomy III` 연구 추가(`FarmYieldBoost` 상위 단계).
- `Soil Science I` 연구 추가(`FarmResilienceBoost`).
### 수정 파일
- `data/research/agronomy_2.tres`
- `data/research/agronomy_3.tres`
- `data/research/soil_science_1.tres`

## 24회차 (5차 반복 4)
### 구현 기능
- `Trap Mechanics I` 연구 추가(`TrapCooldownBoost`).
- `Trap Mechanics II` 연구 추가(`TrapCooldownBoost` 상위 단계).
- `Trap Range II` 연구 추가(`TrapRangeBoost` 상위 단계).
### 수정 파일
- `data/research/trap_mechanics_1.tres`
- `data/research/trap_mechanics_2.tres`
- `data/research/trap_range_2.tres`

## 25회차 (5차 반복 5)
### 구현 기능
- `Scavenging II` 연구 추가(`EnemyDropBoost` 상위 단계).
- `Repair Protocol I` 연구 추가(수리 속도 강화).
- `Logistics II` 연구 추가(운반 긴급도 강화).
### 수정 파일
- `data/research/scavenging_2.tres`
- `data/research/repair_protocol_1.tres`
- `data/research/logistics_2.tres`

---

## 26회차 (6차 반복 1)
### 구현 기능
- 스톡파일 프리셋 `Emergency` 추가.
- 스톡파일 프리셋 `Harvest` 추가.
- HUD 프리셋 목록에 신규 프리셋 노출.
### 수정 파일
- `scripts/core/StockpileZone.gd`
- `scripts/core/MainController.gd`

## 27회차 (6차 반복 2)
### 구현 기능
- 함정 정비 자원 소모를 배치 단위로 확장.
- 누락 충전량 기반 정비 배치 자동 계산.
- 방어 상태에 예상 자원량 표시(`필요 W/S`).
### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/Colonist.gd`

## 28회차 (6차 반복 3)
### 구현 기능
- `command_aura_move_bonus` 메타 필드 확장 유지.
- `CommandPost` 이동 오라 지속 반영.
- `WatchTower` 이동 오라 지속 반영.
### 수정 파일
- `scripts/data/BuildingDef.gd`
- `scripts/systems/BuildSystem.gd`
- `scripts/core/BuildingSite.gd`
- `data/buildings/command_post.tres`
- `data/buildings/watch_tower.tres`

## 29회차 (6차 반복 4)
### 구현 기능
- `BattleDrillI`에 `SignalFire` 해금 연동 유지.
- `DisciplineI` 기반 `DrillYard` 해금 라인 확장.
- 지원 건물 조합(지휘+농장) 전략 루프 강화.
### 수정 파일
- `data/research/battle_drill_1.tres`
- `data/research/discipline_1.tres`
- `data/buildings/signal_fire.tres`
- `data/buildings/drill_yard.tres`

## 30회차 (6차 반복 5)
### 구현 기능
- 주야 적 보정/함정 보정/농장 보정을 단일 런타임 루프로 통합.
- 연구 보너스 적용 분기 확장(누적 12종 이상) 안정화.
- 4~6차 반복 기능을 `job.md` 30회차까지 누적 기록 완료.
### 수정 파일
- `scripts/core/MainController.gd`
- `scripts/core/FarmZone.gd`
- `job.md`

### 검증 결과 (4~6차 반복 공통)
- 수정 스크립트 린트 오류 없음.
- 신규 연구/건물 리소스 파일 파싱 가능 형식으로 추가 완료.
- 기존 시스템과 충돌 없이 메타/그룹 기반 확장 경로 유지.
