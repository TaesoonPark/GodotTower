# ColonySimPrototype

Godot 4.6 기반 림월드 라이크 콜로니 시뮬레이터 프로토타입입니다.

## 현재 상태

- RTS 입력: 단일 선택/드래그 다중 선택/우클릭 즉시 이동 명령
- 액션 패널: `Move`, `Build`, `Gather`, `Blueprint`, `StockpileZone` 전환
- 주민 상태: `Health`, `Hunger`, `Rest`, `Mood`
- 작업 시스템: 우선순위 + 주민별 작업 On/Off 기반 자동 할당(`BuildSite`, `Gather`, `HaulResource`, `CraftRecipe` 포함)
- 건축 시스템: 하단 카탈로그 기반 건물 선택 + 즉시 건축/청사진 배치
- 채집/운반 시스템: 채집물 드랍 생성 -> 저장구역으로 자동 운반 후 재고 반영
- 제작 시스템: 작업대 + 레시피 큐(좌측 패널에서 큐 등록)
- UI: 좌측 액션/상태/작업토글/제작큐 패널 + 하단 건축 목록 + 자원 스톡 표시

상세 정리와 TODO는 `docs/STATUS_AND_TODO.md`를 참고하세요.

## 실행

```bash
godot --path .
```

또는 Godot 에디터에서 프로젝트를 열어 실행하세요.

자동 플레이테스트:

```bash
bash scripts/run-playtest.sh
```

실제 GUI 클릭/드래그 플레이테스트:

```bash
bash scripts/run-gui-playtest.sh
```

자동 셀프체크 루프:

```bash
bash scripts/self-check.sh
```

## 기본 해상도

- `1920 x 1080 (FHD)`

## 조작

- `M`: 이동/선택 액션
- `B`: 즉시 건축 액션
- `G`: 채집 지시 액션
- `P`: 청사진 배치 액션
- `Z`: 저장구역 지정 액션(드래그)
- 좌클릭: 현재 액션 실행
- 우클릭: 선택 주민 즉시 이동

## 림월드라이크 확장용 데이터 시드

- 건물 정의: `data/buildings` (`Wall`, `Floor`, `Stockpile`, `SimpleBench`)
- 자원 정의: `data/resources` (`Wood`, `Stone`, `Steel`, `FoodRaw`, `Meal`)
- 작업대 정의: `data/workstations/simple_bench_station.tres`
- 레시피 정의: `data/recipes` (`CutStone`, `CookMeal`, `MakeBed`)

## 프로젝트 구조

- `scenes/main` : 메인 진입 씬
- `scenes/world` : 월드/내비게이션/건설 사이트
- `scenes/units` : 주민 유닛
- `scenes/ui` : HUD
- `scripts/core` : 메인/주민/HUD 핵심 로직
- `scripts/systems` : 입력/욕구/작업/건축 시스템
- `scripts/data` + `data` : 커스텀 Resource 스키마와 인스턴스

## MCP / 플레이테스트

기존 프로젝트 내부 MCP 플러그인 의존성은 제거했습니다.
이제 MCP는 외부 서버 방식으로 연결합니다.

설정 및 플레이테스트 절차:

- `docs/GODOT_MCP_PLAYTEST.md`
