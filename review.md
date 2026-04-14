# GodotTower 구현 리뷰 업데이트 (2026-04-14)

## 1. 기준
- 작업 브랜치 기준 최신 로컬 구현 상태 반영
- 실행 바이너리 경로: `D:\GodotTower\engine\Godot_v4.6.1-stable_win64_console.exe`
- 본 문서는 최근 전투/소집/UI 리뉴얼 및 핫픽스 반영 내용을 중심으로 정리

## 2. 이번 사이클 핵심 변경

### 2.1 전투/AI 동작 보정
- 장거리 무기 보유 유닛이 불필요하게 적에게 접근하던 동작을 수정.
- 사거리 안에서는 후퇴 없이 즉시 사격하도록 정리.
- 사거리 밖일 때는 전투를 위해 자동 접근하지 않도록 제한.
- 습격 적(약탈자)도 정착민과 동일한 장비 시스템을 사용하도록 통합.
- 습격 적 사망 시 장착 장비를 드랍하도록 변경하고, 기존 고정 자원 보상 경로는 제거.

### 2.2 소집장소(Rally) 기본 비활성화
- 게임 시작 시 자동 소집장소 생성 로직 제거.
- 전투 모드에서도 `RallyFlag`가 실제로 생성된 이후에만 rally 좌표를 전달하도록 변경.
- 최초 `SetRallyFlag` 클릭 시 기존 로직대로 깃발 생성/위치 지정/집결 로직 활성화.

### 2.3 연구 요구량 조정
- 연구 요구 진행도를 기존 대비 1/10 수준으로 축소(연구 진행 속도 체감 개선 목적).

### 2.4 HUD/UI 리뉴얼 반영
- 상단: 자원 바 유지.
- 좌측: 주민 초상화 세로 스크롤 패널 추가(클릭 시 월드 유닛 클릭과 동일 선택 처리).
- 우측: 선택 대상 정보 통합 패널(유닛/건물/자원/농경/재고/장비/상태).
- 하단: 컨텍스트 카탈로그 창(건축/연구/농경/제작), 가로 스크롤 아이템 구조.
- 우하단: 2x3 기능 버튼 구역으로 액션 통합.
  - `StockpileZone`, `DragGather`, `FarmZone`, `Build`, `Work/Combat`, `SetRallyFlag`
- 카탈로그 정책: 기본 닫힘 + 컨텍스트 선택 시 자동 열림/해제 시 자동 닫힘.

## 3. UI 핫픽스(최근)

### 3.1 주민 초상화 클릭 미동작
원인:
- HUD 주기 갱신 시 초상화 버튼이 계속 재생성되어 클릭 타이밍이 씹힘.

조치:
- `scripts/ui/HUDRosterPanel.gd`
  - `set_entries()`에서 기존 데이터와 동일하면 `_rebuild_buttons()`를 건너뛰도록 수정.

### 3.2 농경지 작물 클릭 미동작
원인:
- 카탈로그 아이템이 주기적으로 재생성되어 클릭 일관성이 깨짐.

조치:
- `scripts/ui/HUDCatalogPanel.gd`
  - `set_items()`에서 동일 목록/동일 선택값이면 재빌드 생략.
- `scripts/core/HUDController.gd`
  - `set_farm_catalog()`에서 설명 텍스트 갱신과 아이템 재구성을 분리.

### 3.3 하단 창 겹침 조정
- `scenes/ui/HUD.tscn`의 `BottomCatalogPanel` 앵커를 좌측으로 이동해 우하단 버튼 구역과 겹침 완화.

### 3.4 시작 직후 Cook(제작) 하단 창 자동 오픈 문제
원인:
- 워크스테이션 목록 초기화 시 기본 선택에서 `workstation_changed`가 즉시 emit되어 Craft 카탈로그가 열림.

조치:
- `scripts/core/HUDController.gd`
  - `set_workstation_catalog()`의 초기 emit 제거.
  - `set_craft_panel_visible(false)` 시 Craft 카탈로그가 열려 있으면 함께 닫도록 보강.

검증:
- 스타트업 프로브 결과: `STARTUP_CATALOG_VISIBLE:false`

## 4. 테스트/검증 결과
- Headless 실행(프로젝트 로드) 정상.
- `CombatParitySmokeTest` PASS
- `RtsControlSmokeTest` (`PLAYTEST_INCLUDE_RAID=1`) PASS
- `ResearchParitySmokeTest` PASS

## 5. 주요 변경 파일
- `scenes/ui/HUD.tscn`
- `scripts/core/HUDController.gd`
- `scripts/core/MainController.gd`
- `scripts/ui/HUDRosterPanel.gd`
- `scripts/ui/HUDCatalogPanel.gd`

## 6. 남은 점검 포인트
- UI 텍스트 인코딩(깨진 문자열) 잔여 구간 추가 스캔 및 정리.
- 대형 파일 분리 작업(`MainController.gd`, `HUDController.gd`)은 후속 리팩터링 범위로 진행 필요.
