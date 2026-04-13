# CUI / Simulation-Core Refactor Plan

## 목표

현재 Godot 씬/노드 중심 구조를 한 번에 뒤엎지 않고, 아래 목표를 단계적으로 달성한다.

1. 핵심 게임 로직을 렌더링/입력과 분리한다.
2. 헤드리스 상태에서 한 틱씩 재현 가능한 디버그 경로를 만든다.
3. 최종적으로는 같은 시뮬레이션 코어 위에
   - CUI 디버그 러너
   - Godot GUI 프런트엔드
   를 동시에 얹을 수 있게 한다.

## 현재 구조의 문제

현재 구조에서 디버깅 비용이 큰 이유는 아래와 같다.

- `MainController.gd`가 오케스트레이션, 경제, 레이드, 연구, HUD 반영까지 동시에 들고 있다.
- `Colonist.gd`는 이동/AI/작업 완료/월드 오브젝트 접근을 한 파일에서 직접 처리한다.
- `JobSystem.gd`는 비교적 분리돼 있지만, 여전히 Godot 노드와 `instance_from_id()`, `global_position`에 강하게 의존한다.
- 테스트는 존재하지만, 상태를 구조적으로 관찰하는 인터페이스가 부족하다.

## 권장 아키텍처

### 1. Simulation Core

렌더링/씬과 무관한 순수 상태 계층.

예상 책임:
- colony state
- colonist state
- job queue / reservation state
- stockpile / drop / build site state
- economy / crafting / research state
- tick progression

권장 원칙:
- `Node`, `Node2D`, `Signal`, `global_position` 직접 참조 금지
- 식별자는 `instance_id` 대신 명시적 `entity_id` 사용
- 상태는 `Dictionary`보다 typed model을 우선

### 2. Runtime Adapter

Godot 월드와 시뮬레이션 코어를 연결하는 계층.

예상 책임:
- 씬 노드 -> sim state 동기화
- sim command -> Godot node 반영
- pathing / animation / camera 같은 엔진 특화 요소 브리지

### 3. Presentation Layer

동일한 상태를 여러 방식으로 보여주는 계층.

- Godot HUD / world renderer
- CUI snapshot / command runner
- smoke test assertions

## 단계별 분리 순서

### Phase 0. 관측 가능성 확보

목표:
- 현재 런타임을 CUI처럼 읽을 수 있게 만든다.

작업:
- 상태 스냅샷 생성기 추가
- colonist/job/drop/stockpile/build site를 정규화된 텍스트로 출력
- 테스트 실패 시 동일 포맷의 스냅샷을 자동 출력

완료 기준:
- 버그 리포트에 “어떤 틱에서 누가 무슨 작업 중이었는지”를 텍스트로 남길 수 있다.

### Phase 1. Job/Economy Read Model 분리

목표:
- 디버깅 가치가 높은 읽기 모델부터 분리한다.

작업:
- `JobSystem` 입력을 `Array[Node]` 대신 정규화된 데이터 구조로 받는 얇은 adapter 추가
- `resource_stock`, `drop`, `stockpile` 상태를 view model로 추출
- reservation state를 explicit struct로 고정

완료 기준:
- 작업 생성과 배정 판단을 노드 없이 재현 가능한 함수로 옮기기 시작한다.

### Phase 2. Colonist Job Execution 분리

목표:
- 가장 큰 디버깅 비용 원인인 `Colonist.gd`의 작업 전이 로직을 분리한다.

우선 분리 대상:
- `HaulResource`
- `Gather`
- `BuildSite`

이유:
- 현재 버그 가능성이 높은 루프
- 상태 전이가 명확함
- GUI 없이도 충분히 검증 가능

완료 기준:
- 작업 상태 전이 함수가 `Colonist` 노드 바깥에서 실행 가능하다.

### Phase 3. Command/Input 분리

목표:
- GUI 입력 없이도 동일한 플레이 흐름을 실행할 수 있게 만든다.

작업:
- `select`, `move`, `designate gather`, `place stockpile`, `queue craft`를 command object로 정의
- Godot input은 command를 생성만 하고, 적용은 공통 runner가 담당

완료 기준:
- 동일한 command sequence를 GUI와 CUI에서 공유할 수 있다.

### Phase 4. Headless Simulation Runner

목표:
- Godot 렌더링 없이 시뮬레이션만 재생한다.

작업:
- tick loop runner
- scenario loader
- structured log emitter
- diffable snapshot output

완료 기준:
- “운송 정지”, “건설 자재 공급 실패”, “제작 슬롯 교착” 같은 문제를 Godot 창 없이 재현 가능하다.

## 실제 시작 지점

현재 코드 기준으로 가장 먼저 손대야 하는 모듈은 아래 순서다.

1. `MainController.gd`
   - 이유: 상태 집계 지점이 여기 모여 있다.
   - 작업: snapshot extraction, read-model export

2. `JobSystem.gd`
   - 이유: 작업 생성/예약/배정 규칙이 명시돼 있다.
   - 작업: pure scoring / reservation cleanup 함수화

3. `Colonist.gd`
   - 이유: 실행 상태머신이 크다.
   - 작업: `HaulResource`, `Gather`, `BuildSite` 전이를 우선 분리

## 이번 변경에서 추가한 첫 단계

이번 턴에서는 아래를 1차 착수로 본다.

- CUI 스타일 상태 스냅샷 유틸 추가
- 헤드리스에서 상태를 텍스트로 출력하는 디버그 러너 추가

이 둘은 코어 분리 전에도 즉시 디버깅 가치가 있다.

## 하지 말아야 할 것

- 처음부터 전체 엔티티를 ECS로 갈아엎기
- UI까지 동시에 재작성하기
- 모든 시스템을 한 번에 pure model로 옮기기

이 프로젝트는 점진적 전환이 맞다.

## 다음 구현 우선순위

1. `HaulResource` 상태 전이 pure function 추출
2. reservation snapshot / diff 출력 강화
3. job scoring pure helper 분리
4. command sequence runner 추가
