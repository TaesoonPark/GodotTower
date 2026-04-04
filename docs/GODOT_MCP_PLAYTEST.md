# Godot MCP Run/Playtest Setup

이 프로젝트는 더 이상 프로젝트 내부 Godot MCP 플러그인이나 오토로드에 의존하지 않습니다.
MCP는 에디터 밖에서 실행되는 외부 서버가 담당합니다.

현재 권장 런타임은 `@coding-solo/godot-mcp`입니다.

선정 이유:
- `run_project`
- `stop_project`
- `get_debug_output`
- `launch_editor`

위 도구가 이미 제공되어, 프로젝트 실행과 테스트 씬 기반 플레이테스트에 바로 사용할 수 있습니다.

## 근거

- Godot 공식 문서: Godot는 CLI에서 `--path`로 프로젝트를 지정하고, 특정 씬을 직접 실행할 수 있습니다.
- `Coding-Solo/godot-mcp` README: Godot 에디터 실행, 프로젝트 실행, 디버그 출력 수집, 실행 중지 도구를 제공합니다.

참고 링크:
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- https://github.com/Coding-Solo/godot-mcp
- https://context7.com/godotengine/godot-docs

## Cursor 설정

이 저장소에는 프로젝트 전용 Cursor MCP 설정이 이미 들어 있습니다.

파일:
- `.cursor/mcp.json`

현재 설정은 아래 스크립트를 통해 MCP 서버를 띄웁니다.
- `scripts/start-godot-mcp.sh`

이 스크립트는:
- `GODOT_PATH`가 있으면 우선 사용
- 없으면 PATH 및 WSL 경로 후보를 탐색
- 마지막에 `npx -y @coding-solo/godot-mcp`를 실행

## 현재 Godot 경로

이 저장소 기본 설정은 프로젝트 내부 Linux Godot 바이너리를 사용합니다.

`/home/parkts/tower/GodotTower/tools/godot-linux/Godot_v4.6.1-stable_linux.x86_64`

경로가 바뀌었으면 `.cursor/mcp.json` 또는 MCP 클라이언트 환경 변수의 `GODOT_PATH`만 수정하면 됩니다.

WSL에서 Windows exe 직접 호출은 환경에 따라 실패할 수 있으므로, 이 프로젝트는 네이티브 Linux 바이너리를 우선 사용합니다.

## 환경 준비

로컬 Linux Godot 바이너리와 GUI 자동화 가상환경이 없으면 아래 스크립트로 준비합니다.

```bash
bash scripts/setup-playtest-env.sh
```

## 직접 실행

Cursor에서 MCP 서버가 정상 등록되면, 아래 순서로 확인합니다.

1. MCP 서버 `godot`가 enabled 상태인지 확인
2. 툴 목록에 `get_godot_version`이 보이는지 확인
3. `run_project`로 메인 씬 실행
4. `get_debug_output`으로 런타임 로그 확인
5. 필요 시 `stop_project`

## 플레이테스트 방식

현재 가장 안정적인 방식은 "테스트 씬 실행"입니다.

메인 게임 실행:
- `run_project`
- `projectPath`: 프로젝트 루트

자동 플레이테스트 실행:
- `run_project`
- `projectPath`: 프로젝트 루트
- `scene`: `res://scenes/tests/RtsControlSmokeTest.tscn`

이 테스트는 현재 아래 범위를 확인합니다.
- 주민 스폰
- 단일 선택
- 드래그 선택
- 이동 명령
- 건축 등록

기본 스모크에서는 알려진 습격 이슈를 피하기 위해 습격 검증을 생략합니다.
습격까지 강제 검증하려면 `PLAYTEST_INCLUDE_RAID=1`을 설정합니다.

## 실제 GUI 플레이테스트

실제 마우스 클릭/우클릭/드래그를 보내는 GUI 플레이테스트도 추가했습니다.

실행:
- `bash scripts/run-gui-playtest.sh`

현재 시나리오:
- Godot 창 실행
- 첫 주민 클릭
- 다른 위치로 우클릭 이동
- 드래그 박스 선택
- `Campfire` 건축 버튼 클릭
- 맵에 작업대 배치
- 주민이 실제로 건설 완료할 때까지 대기

구현 파일:
- `scripts/gui_playtest.py`
- `scripts/run-gui-playtest.sh`

## 자동 셀프체크 루프

구현 후 기본 확인 루프:

```bash
bash scripts/self-check.sh
```

동작:
- 변경 파일 감지
- headless 스모크 항상 실행
- raid 스모크 기본 실행
- UI 관련 변경일 때 GUI 플레이테스트 자동 실행
- 로그와 셀프 피드백 요약을 `artifacts/self-check/<timestamp>/` 에 저장

옵션:
- `SELF_CHECK_GUI=1 bash scripts/self-check.sh`
- `SELF_CHECK_GUI=0 bash scripts/self-check.sh`
- `SELF_CHECK_RAID=1 bash scripts/self-check.sh`
- `SELF_CHECK_RAID=0 bash scripts/self-check.sh`

주의:
- 이 경로는 데스크톱 세션 접근이 필요하므로 샌드박스 안에서는 막힐 수 있습니다.
- 현재 환경에서는 입력 주입은 정상 동작했지만, 루트 화면 스크린샷은 X11/XWayland 조합에 따라 `BadMatch`로 건너뛸 수 있습니다.

파일:
- `scenes/tests/RtsControlSmokeTest.tscn`
- `scripts/tests/RtsControlSmokeTest.gd`

## 한계

이 구성은 "프로젝트 실행 + 로그 수집 + 테스트 씬 기반 플레이테스트"에는 적합합니다.
반면 사람이 화면을 보며 클릭/드래그/키입력을 직접 주입하는 범용 GUI 자동화까지 보장하지는 않습니다.

그런 인터랙션이 필요하면 두 가지 중 하나로 가야 합니다.
- 테스트 씬/테스트 스크립트에 조작 시나리오를 코드로 추가
- 별도 GUI 자동화 도구를 MCP와 조합

이 프로젝트에는 첫 번째 방식이 더 맞습니다.

## 문제 해결

`godot` 서버가 안 뜰 때:
- Cursor Settings > MCP에서 refresh
- `GODOT_PATH` 경로 확인
- `node`/`npx` 설치 확인

`run_project`는 되는데 반응이 없을 때:
- `get_debug_output` 먼저 확인
- 테스트 씬을 직접 지정해서 재시도

`project.godot` 관련 에러가 날 때:
- 이 프로젝트는 내부 MCP plugin/autoload를 제거했으므로, 에디터 플러그인 누락 에러가 나오면 이전 캐시나 외부 설정을 확인
