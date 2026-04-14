# GodotTower 프로젝트 코드 리뷰 (2026-04-13 업데이트)

## 1. 검토 기준

- 기준 브랜치: `main`
- 기준 커밋: `aae8d5d` (`origin/main`과 동기화 상태)
- 목적: 현재 코드 구조, 테스트 체계, 운영 리스크를 최신 상태로 정리

## 2. 한줄 결론

기존 런타임 중심 구조는 유지되지만, 이번 상태에서 가장 큰 변화는 `scripts/sim` 기반의 시뮬레이션 코어와 `parity smoke test` 체계가 도입되어 "재현 가능한 디버깅/검증" 역량이 크게 강화됐다는 점이다.

## 3. 현재 규모 (실측)

### 3.1 파일/라인 통계

| 항목 | 수치 |
|---|---:|
| `scripts/**/*.gd` 파일 수 | 63 |
| `scripts/**/*.gd` 총 라인 수 | 14,232 |
| `scenes/**/*.tscn` 파일 수 | 36 |
| `data/**/*.tres` 파일 수 | 70 |
| 테스트 스크립트 (`scripts/tests/*.gd`) | 24 |
| 테스트 씬 (`scenes/tests/*.tscn`) | 24 |

### 3.2 핵심 파일 크기

| 파일 | 라인 수 | 함수 수 |
|---|---:|---:|
| `scripts/core/MainController.gd` | 3,995 | 228 |
| `scripts/systems/JobSystem.gd` | 1,205 | 71 |
| `scripts/core/Colonist.gd` | 1,369 | 82 |
| `scripts/core/HUDController.gd` | 1,219 | 72 |
| `scripts/core/EnemyUnitBase.gd` | 477 | 38 |
| `scripts/systems/BuildSystem.gd` | 286 | 23 |
| `scripts/core/FarmZone.gd` | 447 | 30 |

## 4. 아키텍처 현황

### 4.1 런타임 계층 (Godot 노드 기반)

- 메인 진입: `scenes/main/Main.tscn`
- 핵심 오케스트레이터: `MainController`
- 시스템 노드: `InputController`, `NeedSystem`, `JobSystem`, `BuildSystem`
- 월드/유닛/HUD는 기존 구조 유지

핵심 루프는 여전히 `MainController._process()` + `dirty dispatch` 구조로 돌아가며, `JobSystem.process_dirty()`를 통해 작업 생성/정리/할당을 단계적으로 처리한다.

### 4.2 적 유닛 구조 리팩터링

- `Raider.gd`, `Zombie.gd`는 경량화됨
- 공통 AI/이동/전투 로직은 `EnemyUnitBase.gd`로 승격

결과적으로 적 타입별 차이는 프로파일(스탯/무기 성향) 중심으로 축소되어 유지보수성이 개선됐다.

### 4.3 시뮬레이션 코어 계층 신설

신규 디렉토리:
- `scripts/sim/` (`StateRunner`, `JobScoring`, `*Transition`, `HaulReservationLogic`)
- `scripts/debug/` (`CommandSequenceRunner`, `ScenarioTraceRunner`, `SimulationSnapshot`)

의의:
- 런타임 노드 로직과 별개로, 딕셔너리 기반 상태 머신을 헤드리스로 재생 가능
- 런타임 결과와 pure simulation 결과를 비교하는 parity 테스트 기반이 마련됨

## 5. 테스트/검증 체계

### 5.1 테스트 씬 기반 스모크

`scenes/tests/*.tscn` + `scripts/tests/*.gd` 조합으로 다음 축을 검증:
- RTS 제어
- Gather/Haul 루프
- Build/Craft/Research/Repair/Trap 유지보수
- Combat/Parity/Command sequence

### 5.2 자동 실행 스크립트

- `scripts/run-playtest.sh`: 기본 headless 스모크
- `scripts/run-parity-suite.sh`: parity 씬 일괄 실행
- `scripts/run-gui-playtest.sh`: GUI 입력 기반 시나리오
- `scripts/self-check.sh`: 변경 파일 기반 자동 검사 루프

이전 리뷰와 달리, 현재는 테스트 부재가 아니라 "스모크 중심 테스트 인프라가 충분히 구축된 상태"로 보는 게 맞다.

## 6. 데이터/콘텐츠 상태

### 6.1 Resource 기반 데이터 정의

정의 스크립트(`scripts/data`)는 유지:
- `BuildingDef`, `RecipeDef`, `WorkstationDef`, `ResearchDef`, `CropDef`, `ResourceDef`, `ColonistStatsData`, `ColonistLoadoutData`, `JobPriorityData`

### 6.2 데이터 인스턴스 수

| 디렉토리 | 개수 |
|---|---:|
| `data/buildings` | 19 |
| `data/resources` | 12 |
| `data/recipes` | 11 |
| `data/research` | 22 |
| `data/workstations` | 2 |
| `data/crops` | 1 |
| `data/colonists` | 2 |
| `data/priorities` | 1 |

## 7. 운영/도구 체계 변화

- 프로젝트 내부 MCP 플러그인 의존이 제거됨 (`addons/` 없음)
- `project.godot`에도 MCP autoload/editor plugin 설정이 없음
- MCP는 외부 서버 방식 문서(`docs/GODOT_MCP_PLAYTEST.md`)로 운영

즉, 런타임 프로젝트는 순수 게임 로직에 집중하고, 도구 체인은 외부로 분리하는 방향으로 전환됐다.

## 8. 강점

1. 런타임 + 시뮬레이션 이중 검증 루트 확보
2. 적 유닛 공통 로직 추출로 중복 제거
3. 데이터 드리븐 구조 지속 유지 (콘텐츠 확장 용이)
4. 헤드리스/GUI/self-check 스크립트가 분리되어 운영 선택지가 명확

## 9. 리스크와 개선 우선순위

1. `MainController` 비대화는 여전히 가장 큰 구조적 리스크
2. 런타임 로직과 `scripts/sim` 로직의 장기 드리프트 위험
3. 일부 문자열/주석의 인코딩 깨짐(표시 품질 저하, 가독성 문제)
4. 테스트는 스모크 중심이라, 정밀 회귀(경계값/랜덤성 제어) 보강 여지 존재

## 10. 권장 다음 단계

1. `MainController`를 도메인 단위(raid/economy/research/ui sync)로 분리
2. `JobSystem` 핵심 스코어링/예약 정리 함수를 sim-core와 공유 가능한 형태로 통합
3. parity 실패 시 diff 출력을 더 구조화(JSON artifact 고정 경로)
4. 인코딩 깨짐 문자열 정리(특히 HUD/라벨/테스트 로그 메시지)

---

이 문서는 현재 `main`의 실측 수치와 실제 파일 구조를 기준으로 갱신되었다.
