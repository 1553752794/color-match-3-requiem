from __future__ import annotations

import argparse
import random
from collections import Counter
from dataclasses import dataclass


COLORS = ("gray", "red", "blue", "gold")
PROFILES = {
    "legacy": (0.66, 0.115, 0.115, 0.11),
    "v12_base": (0.43, 0.19, 0.19, 0.19),
    "v12_pressure": (0.50, 0.17, 0.17, 0.16),
}


@dataclass
class Sample:
    valid_moves: int = 0
    cleared: int = 0
    cascades: int = 0
    max_cascade: int = 0
    deadlocks: int = 0


def weighted_color(rng: random.Random, weights: tuple[float, ...]) -> str:
    return rng.choices(COLORS, weights=weights, k=1)[0]


def find_matches(board: list[list[str]]) -> set[tuple[int, int]]:
    rows = len(board)
    cols = len(board[0])
    matched: set[tuple[int, int]] = set()
    for y in range(rows):
        start = 0
        for x in range(1, cols + 1):
            if x < cols and board[y][x] == board[y][start]:
                continue
            if x - start >= 3:
                matched.update((px, y) for px in range(start, x))
            start = x
    for x in range(cols):
        start = 0
        for y in range(1, rows + 1):
            if y < rows and board[y][x] == board[start][x]:
                continue
            if y - start >= 3:
                matched.update((x, py) for py in range(start, y))
            start = y
    return matched


def make_board(
    size: int, rng: random.Random, weights: tuple[float, ...]
) -> list[list[str]]:
    while True:
        board: list[list[str]] = []
        for y in range(size):
            row: list[str] = []
            for x in range(size):
                candidates = list(COLORS)
                rng.shuffle(candidates)
                candidates.sort(key=lambda color: weights[COLORS.index(color)], reverse=True)
                for _ in range(24):
                    candidate = weighted_color(rng, weights)
                    horizontal = x >= 2 and row[x - 1] == candidate == row[x - 2]
                    vertical = y >= 2 and board[y - 1][x] == candidate == board[y - 2][x]
                    if not horizontal and not vertical:
                        row.append(candidate)
                        break
                else:
                    row.append(next(color for color in candidates if not (
                        (x >= 2 and row[x - 1] == color == row[x - 2])
                        or (y >= 2 and board[y - 1][x] == color == board[y - 2][x])
                    )))
            board.append(row)
        if possible_swaps(board):
            return board


def possible_swaps(board: list[list[str]]) -> list[tuple[tuple[int, int], tuple[int, int]]]:
    rows = len(board)
    cols = len(board[0])
    swaps: list[tuple[tuple[int, int], tuple[int, int]]] = []
    for y in range(rows):
        for x in range(cols):
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if nx >= cols or ny >= rows or board[y][x] == board[ny][nx]:
                    continue
                board[y][x], board[ny][nx] = board[ny][nx], board[y][x]
                if find_matches(board):
                    swaps.append(((x, y), (nx, ny)))
                board[y][x], board[ny][nx] = board[ny][nx], board[y][x]
    return swaps


def resolve(
    board: list[list[str]], rng: random.Random, weights: tuple[float, ...]
) -> tuple[int, int]:
    total = 0
    cascades = 0
    while True:
        matched = find_matches(board)
        if not matched:
            return total, cascades
        cascades += 1
        total += len(matched)
        rows = len(board)
        cols = len(board[0])
        for x in range(cols):
            kept = [board[y][x] for y in range(rows) if (x, y) not in matched]
            refill = [weighted_color(rng, weights) for _ in range(rows - len(kept))]
            column = refill + kept
            for y, color in enumerate(column):
                board[y][x] = color


def simulate(
    size: int,
    boards: int,
    turns_per_board: int,
    seed: int,
    weights: tuple[float, ...],
) -> Sample:
    rng = random.Random(seed)
    sample = Sample()
    for _ in range(boards):
        board = make_board(size, rng, weights)
        for _ in range(turns_per_board):
            swaps = possible_swaps(board)
            sample.valid_moves += len(swaps)
            if not swaps:
                sample.deadlocks += 1
                board = make_board(size, rng, weights)
                continue
            first, second = rng.choice(swaps)
            board[first[1]][first[0]], board[second[1]][second[0]] = (
                board[second[1]][second[0]],
                board[first[1]][first[0]],
            )
            cleared, cascades = resolve(board, rng, weights)
            sample.cleared += cleared
            sample.cascades += cascades
            sample.max_cascade = max(sample.max_cascade, cascades)
            if not possible_swaps(board):
                sample.deadlocks += 1
                board = make_board(size, rng, weights)
    return sample


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--boards", type=int, default=5000)
    parser.add_argument("--turns", type=int, default=3)
    parser.add_argument("--seed", type=int, default=20260727)
    args = parser.parse_args()
    observations = args.boards * args.turns
    for profile_name, weights in PROFILES.items():
        for size in (6, 7):
            result = simulate(size, args.boards, args.turns, args.seed + size, weights)
            print(
                f"{profile_name} {size}x{size}: "
                f"avg_valid_moves={result.valid_moves / observations:.3f}, "
                f"avg_cleared={result.cleared / observations:.3f}, "
                f"avg_cascades={result.cascades / observations:.3f}, "
                f"deadlock_rate={result.deadlocks / observations:.5%}, "
                f"max_cascade={result.max_cascade}"
            )


if __name__ == "__main__":
    main()
