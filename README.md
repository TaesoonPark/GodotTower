# ColonySimPrototype

Godot 4.6 기반 식민지 생존/자동화 시뮬레이션 프로토타입입니다.

## 현재 구현 상태

### 핵심 게임플레이
- RTS 입력: 단일 선택, 드래그 다중 선택, 우클릭 이동 명령
- 정착민 상태: Health / Hunger / Rest / Mood
- 작업 시스템: Build / Gather / Haul / Craft / Research / Combat / Hunt 자동 할당
- 건설 시스템: 하단 카탈로그 기반 건물 선택 + 즉시 배치
- 농경 시스템: 농경지 지정, 작물 선택, 성장/수확 루프
- 연구 시스템: 연구 벤치 기반 프로젝트 진행 (요구 진행도 1/10 반영)

### 전투/습격
- 장거리 무기 보유 유닛은 사거리 내 즉시 사격
- 사거리 밖에서 전투를 위해 자동 돌진하지 않도록 조정
- 습격 적(약탈자)도 장비 시스템 사용
- 습격 적 사망 시 착용 장비 드랍

### 소집장소(Rally)
- 게임 시작 시 기본 소집장소는 생성되지 않음
- `집합 깃발`을 최초 지정한 이후에만 rally 로직 활성화

### UI 리뉴얼
- 상단: 정착지 자원 바
- 좌측: 주민 초상화 세로 스크롤 목록 (클릭 시 유닛 선택)
- 우측: 선택 대상 통합 정보창 (유닛/건물/자원/농경/장비/재고)
- 하단: 컨텍스트 카탈로그 창 (건축/연구/농경/제작), 가로 스크롤
- 우하단: 2x3 기능 버튼
  - 저장구역 / 사냥채집 / 농경지 / 건축 / 복장규정 / 집합깃발
- 하단 카탈로그는 기본 닫힘, 컨텍스트 선택 시 자동 열림

## 실행 방법

### Windows (현재 레포 기준)
```powershell
$env:PYTHONUTF8='1'
$env:PYTHONIOENCODING='UTF-8'
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
.\engine\Godot_v4.6.1-stable_win64_console.exe --path .
```

### Windows UTF-8 콘솔 권장 (cmd.exe)
```bat
chcp 65001
set PYTHONUTF8=1
set PYTHONIOENCODING=UTF-8
```

### Godot 에디터
- Godot 에디터에서 프로젝트를 열고 `scenes/main/Main.tscn` 실행

### macOS/WSL/Linux
- 환경에 Godot가 설치되어 있거나 `GODOT_PATH`가 설정되어 있으면:
```bash
export PYTHONUTF8=1
export PYTHONIOENCODING=UTF-8
bash scripts/run-playtest.sh
```

## 테스트

### 인코딩 검증 (공통)
```bash
python3 scripts/check_encoding.py --all
python3 scripts/check_encoding.py --staged
```

### 빠른 스모크 테스트 (Windows)
```powershell
.\engine\Godot_v4.6.1-stable_win64_console.exe --path . --headless res://scenes/tests/CombatParitySmokeTest.tscn
$env:PLAYTEST_INCLUDE_RAID='1'; .\engine\Godot_v4.6.1-stable_win64_console.exe --path . --headless res://scenes/tests/RtsControlSmokeTest.tscn
.\engine\Godot_v4.6.1-stable_win64_console.exe --path . --headless res://scenes/tests/ResearchParitySmokeTest.tscn
```

### 스크립트 기반 실행 (WSL/Linux)
```bash
bash scripts/run-playtest.sh
bash scripts/run-parity-suite.sh
bash scripts/run-gui-playtest.sh
bash scripts/self-check.sh
```

`scripts/self-check.sh`는 시작 시 `python3 scripts/check_encoding.py --all`을 먼저 실행하며,
UTF-8/BOM 정책 위반이 있으면 즉시 실패합니다.

## 조작
- 좌클릭: 선택/액션 수행
- 좌클릭 드래그: 다중 선택 또는 영역 지정(현재 액션 기준)
- 우클릭: 선택 유닛 이동 명령
- 휠: 줌 인/아웃
- 가운데 버튼 드래그: 카메라 이동
- `Space`: 일시정지 토글
- `1/2/3`: 게임 속도 조절
- `Esc`: 배치/액션 취소 후 기본 상호작용 모드 복귀

## 기본 해상도
- 1920 x 1080 (FHD)

## 프로젝트 구조
- `scenes/main`: 메인 진입
- `scenes/world`: 월드/구조물/존 관련 씬
- `scenes/units`: 정착민/적 유닛 씬
- `scenes/ui`: HUD/UI 씬
- `scripts/core`: 메인 루프 및 핵심 게임 로직
- `scripts/systems`: 입력/욕구/작업/건설 시스템
- `scripts/ui`: HUD 하위 UI 컴포넌트
- `scripts/tests`, `scenes/tests`: 스모크/패리티 테스트
- `data`, `scripts/data`: Resource 정의 및 게임 데이터

## Reference Documents
- `docs/README.md`: active docs map
- `review.md`: recent implementation summary
- `docs/PROJECT_STATUS.md`: consolidated status/TODO/history
- `docs/MCP_GUIDE.md`: consolidated MCP + playtest + server comparison guide
- `docs/CUI_SIM_REFACTOR_PLAN.md`: simulation-core refactor plan
