# Kingdom Rush Clone

Godot 4.6 기반의 타워 디펜스 게임

## 설치

Godot 4.6을 설치하세요:
- [Godot Engine 다운로드](https://godotengine.org/download/)

## 실행 방법

```bash
godot4.6 --path /mnt/d/tower /mnt/d/tower/Main.tscn
```

## 게임 기능

- **타워 설치**: 왼쪽 클릭으로 타워 설치 (100 Gold)
- **타워 업그레이드**: 업그레이드 버튼 클릭 (75 Gold)
- **타워 판매**: 판매 버튼 클릭
- **적 웨이브**: 무한 웨이브 시스템
- **적 체력바**: 각 적의 체력 표시

## 주요 파일

- `scripts/GameManager.gd` - 게임 메인 로직
- `scripts/Tower.gd` - 타워 공격 로직
- `scripts/Enemy.gd` - 적 이동 및 체력 시스템
- `scenes/` - 게임 장면 파일들

## 플레이 방법

1. 게임 시작 시 타워 설치 모드로 진입
2. 적이 경로를 따라 이동할 때 타워로 공격
3. 적을 처치하여 돈 획득
4. 돈으로 타워 업그레이드 또는 추가 설치
