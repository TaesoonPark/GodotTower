# 다른 IDE 공유용 프로젝트 정리 및 플레이테스트 가이드

이 문서는 타 IDE에서도 동일하게 프로젝트 상태와 실행/플레이테스트 절차를 재현하기 위한 기록입니다.

## 1) 현재 적용 상태 요약

### 핵심 반영 내용

- 기존 타워디펜스 레거시에서 콜로니 시뮬레이터 기반으로 전환
  - RTS 입력: 단일 선택/드래그 선택/우클릭 이동
  - 식민지 구성원 상태 시스템 및 욕구 갱신
- 건축/청사진 파이프라인
  - 건축 버튼 선택 후 좌클릭으로 블루프린트 배치
  - 블루프린트는 `build_sites` 그룹으로 관리되어 건설 작업과 연동
- 컴뱃/습격 플레이프레임의 기본 골격 유지
- 런타임 검증용 스모크 테스트 추가
  - `scenes/tests/RtsControlSmokeTest.tscn`
  - `scripts/tests/RtsControlSmokeTest.gd`

### 현재 이슈(테스트 상태)

- 스모크 테스트 중 RTS 조작/건축 확인은 통과했습니다.
- `습격(raid)` 강제 호출 시 즉시 `Resolved`로 전환되면서 적 스폰이 보장되지 않는 이슈가 남아 있습니다.
  - 해당 부분은 다음 수정 대상입니다.

## 2) 프로젝트 실행/검증 (공통)

### 공통 실행

1. 프로젝트 루트: `res://` 경로 기준
2. 에디터에서 열기: `scenes/main/Main.tscn`을 기본으로 설정되어 있음
3. 필요 시 스모크 테스트 실행:
   - `run_project` 실행 시 `scene`을 `res://scenes/tests/RtsControlSmokeTest.tscn`로 지정

### MCP 런타임 기본 체크리스트 (권장)

1. `get_godot_version`
2. `run_project` (projectPath: 프로젝트 루트)
3. `get_debug_output`
4. (옵션) `runtime-status`/`runtime` 상태 확인

## 3) 다른 IDE에서 MCP 사용

- 기본 아이디어: `.cursor/mcp.json`은 Cursor 전용이므로, 다른 IDE는 `mcp/godot-mcp.shared.json` 또는 동등한 MCP 서버 설정을 등록합니다.
- MCP 부트스트랩 실행 스크립트
  - `scripts/start-gopeak-mcp.sh` (GoPeak 기반 런타임 사용 시)
  - `scripts/start-godot-mcp.sh` (기존 `@coding-solo/godot-mcp` 기반)

### `scripts/start-gopeak-mcp.sh` 사용 시 참고

- `GODOT_PATH` 자동 탐색 우선순위가 내장되어 있습니다.
- Godot가 검색되지 않으면 실행 전에 `GODOT_PATH`를 수동 지정하세요.

### MCP 서버가 시작되지 않을 때

- 포트 충돌/실행 경로 이슈가 대표적입니다.
- IDE 출력에서 포트(권장: 7777) 연결 상태, 프로젝트 경로 일치 여부를 먼저 확인하세요.

## 4) 변경 파일(핵심)

- `project.godot`  
  - MCP 런타임/에디터 플러그인 활성화, MCPRuntime 오토로드 등록
- `scripts/start-gopeak-mcp.sh`  
  - GoPeak 부트스트랩(후속 실패 방지용 `npm exec --ignore-scripts` 적용)
- `scripts/start-godot-mcp.sh`  
  - Godot 탐색 범위 보강
- `scripts/tests/RtsControlSmokeTest.gd`
- `scenes/tests/RtsControlSmokeTest.tscn`
