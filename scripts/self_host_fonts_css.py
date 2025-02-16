import re
import sys
from pathlib import Path
from urllib.parse import urlparse

import httpx


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


def main() -> None:
    if len(sys.argv) != 5:
        print(
            f"Usage: {sys.argv[0]} <source.css.in> <source.css> <download-dir> <page-dir>",
            file=sys.stderr,
        )

    source_css = download_css_assets(
        Path(sys.argv[1]).read_text(), Path(sys.argv[3]), Path(sys.argv[4])
    )
    Path(sys.argv[2]).write_text(source_css)


if __name__ == "__main__":
    main()
