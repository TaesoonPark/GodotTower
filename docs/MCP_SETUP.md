# MCP 연결 정리 (Cursor/다른 IDE 공용)

이 프로젝트는 Godot MCP 서버로 `@coding-solo/godot-mcp`를 사용합니다.

## 프로젝트 내 설정 파일

- Cursor 전용: `.cursor/mcp.json`
- IDE 공통 템플릿: `mcp/godot-mcp.shared.json`
- 부트스트랩 스크립트: `scripts/start-godot-mcp.sh`

## 부트스트랩 동작

`scripts/start-godot-mcp.sh`는 Godot 실행 파일을 아래 순서로 탐지합니다.

1. `GODOT_PATH` 환경 변수
2. `/Applications/Godot.app/Contents/MacOS/Godot`
3. `~/Applications/Godot.app/Contents/MacOS/Godot`
4. 현재 실행 중인 Godot 프로세스 경로

찾지 못하면 에러를 내고 종료합니다.

## Cursor에서 사용

이미 `.cursor/mcp.json`이 포함되어 있어 보통 추가 설정이 필요 없습니다.

1. Cursor 설정 > MCP에서 `godot` 서버 확인
2. 필요 시 Refresh
3. 아래 순서로 검증
   - `get_godot_version`
   - `run_project` (`projectPath`: 프로젝트 루트)
   - `get_debug_output`

## 다른 IDE/클라이언트에서 사용

해당 IDE의 MCP 설정 파일에 `mcp/godot-mcp.shared.json` 내용을 복사해서 등록하면 됩니다.

핵심은 아래 3가지입니다.

- `command`: `bash`
- `args`: `["scripts/start-godot-mcp.sh"]`
- `env.DEBUG`: `"true"`

IDE에서 작업 디렉터리를 프로젝트 루트로 실행하도록 설정하세요.

## 필요 환경

- Godot 4.6.x
- Node.js 18+
- `npx` 사용 가능 환경

## 트러블슈팅

- `Godot executable not found`
  - `GODOT_PATH`를 직접 지정
  - 예: `export GODOT_PATH="/Applications/Godot.app/Contents/MacOS/Godot"`
- MCP 서버는 뜨는데 툴 호출 실패
  - IDE MCP 로그에서 작업 디렉터리가 프로젝트 루트인지 확인
- 프로젝트 실행은 되는데 디버그 출력이 비어 있음
  - 먼저 `run_project` 호출 후 `get_debug_output`을 호출해야 함
