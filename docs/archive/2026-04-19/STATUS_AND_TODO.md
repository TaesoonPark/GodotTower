# 작업 정리 및 TODO

## 현재까지 작업 내용

### 1) 프로젝트 리셋 및 구조 재구성
- 기존 타워디펜스 전용 씬/스크립트 제거
- 콜로니 시뮬레이터 중심 구조로 재편
  - `scenes/main`, `scenes/world`, `scenes/units`, `scenes/ui`
  - `scripts/core`, `scripts/systems`, `scripts/data`
  - `data/colonists`, `data/priorities`

### 2) 핵심 플레이 루프(MVP)
- RTS 입력
  - 좌클릭 단일 선택
  - 드래그 박스 다중 선택
  - 우클릭 이동 명령
- 마우스 액션 UI
  - `Move`, `Build`, `Gather`, `Blueprint` 전환
  - 좌측 액션 패널 + 하단 건축 카탈로그
- 주민 상태/욕구
  - `Health`, `Hunger`, `Rest`, `Mood`
  - 틱 기반 갱신
- 작업 우선순위
  - `Haul`, `Build`, `Craft`, `Combat`, `Idle`, `EatStub`
  - UI 슬라이더로 조정 가능
- 작업 시스템
  - 우선순위 점수 기반 할당
  - 필요 작업(`EatStub`, `IdleRecover`) 자동 생성
- 건축 시스템
  - 건물 정의(`data/buildings`) 기반 선택
  - `Build`: 즉시 건축(개발용)
  - `Blueprint`: 청사진 배치 후 건설 작업 생성
  - 주민이 이동해 건설 진행 및 완공
- 채집 시스템
  - 맵 `gatherables` 지시 -> `Gather` 작업 생성
  - 주민 채집 시 자원 스톡 누적(`Wood`, `Stone` 등)

### 2-1) 림월드라이크 확장 시드 데이터
- 자원 정의: `data/resources`
- 작업대 정의: `data/workstations`
- 레시피 정의: `data/recipes`
- 초기 추천 루프:
  - `FoodRaw -> Meal` (CookMeal)
  - `Stone -> StoneBlock` (CutStone)
  - `Wood -> Bed` (MakeBed)

### 3) 명령 처리 정책
- 새 이동 명령 입력 시:
  - 기존 대기 큐 제거
  - 현재 작업 취소
  - 새 명령 즉시 실행

### 4) 런타임 검증
- 외부 Godot MCP의 `run_project` + `get_debug_output` 기준 치명 오류 없음

## 현재 TODO (우선순위)

### High
- 건축 자원 연동 (재료 요구량/보유량/소모)
- 건물 타입 확장 (벽/문/작업대)
- 건설 취소/철거/환불 로직

### Medium
- 제작 시스템 (레시피, 제작 큐, 작업대 연계)
- 운반/저장 시스템 (아이템 스택, 창고)
- 주민 작업 예약 충돌 방지 (동시 접근 락)

### Medium
- 전투 시스템 뼈대 (적대 유닛, 사거리, 피해/회복)
- 경비/전투 우선순위와 작업 시스템 연동

### Low
- 카메라 UX 개선 (엣지 스크롤, 줌 단계)
- UI 반응형 레이아웃 고도화
- 저장/불러오기(세이브) 도입

### Farming Backlog
- [ ] 작물 확장: `Potato` 외 `Corn`, `Wheat` 등 추가 + 각 작물 `.tres` 밸런스(성장시간/파종시간/수확시간/수확량) 분리 관리
