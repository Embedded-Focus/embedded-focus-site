import asyncio
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

import httpx


async def fetch_all(urls: list[str]):
    contents = []
    async with httpx.AsyncClient() as client:
        tasks = [client.get(url, follow_redirects=True) for url in urls]
        responses = await asyncio.gather(*tasks)
        for response in responses:
            response.raise_for_status()
            contents.append(response.content.decode("utf-8"))
    return contents


def download_css_assets(css_text: str, save_path: Path, url_path: Path) -> str:
    save_path.mkdir(parents=True, exist_ok=True)

    url_pattern = re.compile(r'url\(["\']?(https?://[^"\'\)]+)["\']?\)')

    def replace_match(match):
        url = match.group(1)
        parsed_url = urlparse(url)
        filename = parsed_url.path.strip("/").split("/")[-1] or "index.html"
        download_path = save_path / filename

        if not download_path.exists():
            try:
                response = httpx.get(url, follow_redirects=True)
                response.raise_for_status()
                download_path.write_bytes(response.content)
            except httpx.RequestError:
                return match.group(0)  # Return unmodified if download fails

        return f'url("{url_path / filename}")'

    modified_css = url_pattern.sub(replace_match, css_text)
    return modified_css


BASE_URL: str = "https://fonts.googleapis.com/css2?family={family}&display=swap"
URL: str = "https://fonts.googleapis.com/css2?family=Barlow:wght@500;700&display=swap"


def main() -> None:
    if len(sys.argv) != 5:
        print(
            f"Usage: {sys.argv[0]} <theme.json> <source.css> <download-dir> <page-dir>",
            file=sys.stderr,
        )

    theme = json.loads(Path(sys.argv[1]).read_text())
    font_families = theme["fonts"]["font_family"]
    urls = [
        f"https://fonts.googleapis.com/css2?family={family}&display=swap"
        for family in [font_families["primary"], font_families["secondary"]]
    ]

    source_css = download_css_assets(
        "\n".join(asyncio.run(fetch_all(urls))), Path(sys.argv[3]), Path(sys.argv[4])
    )
    Path(sys.argv[2]).write_text(source_css)


if __name__ == "__main__":
    main()
