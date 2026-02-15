#!/usr/bin/env python3
"""
Gemini Image Generation CLI
Supports both standard (fast) and pro (high quality) models
"""

import argparse
import os
import sys
import time
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    from google import genai
    from google.genai import types
    from PIL import Image
    import yaml
except ImportError:
    print("Error: Required packages not installed.")
    print("Please run: pip install -r requirements.txt")
    sys.exit(1)


class GeminiImageCLI:
    # Model identifiers (per Google docs: https://ai.google.dev/gemini-api/docs/image-generation)
    # Pro model: supports 1K, 2K, 4K resolutions - higher quality, slower
    MODEL_PRO = "gemini-3-pro-image-preview"
    # Flash model: fixed ~1K resolution only (no imageSize param) - faster generation
    MODEL_FLASH = "gemini-2.5-flash-image"

    # Supported aspect ratios (both models)
    ASPECT_RATIOS = ["1:1", "3:4", "4:3", "2:3", "3:2", "4:5", "5:4", "16:9", "9:16", "21:9"]

    # Supported resolutions (Pro model only - Flash is fixed at ~1K)
    RESOLUTIONS = ["1K", "2K", "4K"]

    def __init__(self, api_key: Optional[str] = None):
        """Initialize the CLI with API credentials."""
        # Get API key from parameter or environment variable
        # Note: Claude Code injects env vars from settings.local.json automatically
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY")

        if not self.api_key:
            print("Error: No API key found!")
            print("Please set GEMINI_API_KEY environment variable or provide via --api-key")
            sys.exit(1)

        # Initialize the client
        try:
            self.client = genai.Client(api_key=self.api_key)
        except Exception as e:
            print(f"Error initializing Gemini client: {e}")
            sys.exit(1)

    def _save_metadata(self, metadata: Dict[str, Any], output_path: str) -> str:
        """Save metadata as YAML file alongside the image."""
        output = Path(output_path)
        metadata_path = output.parent / f"{output.stem}_metadata.yaml"

        with open(metadata_path, 'w') as f:
            yaml.dump(metadata, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

        return str(metadata_path)

    def generate_image(
        self,
        prompt: str,
        images: Optional[List[str]] = None,
        aspect_ratio: str = "1:1",
        resolution: str = "2K",
        output: str = "output.png",
        use_pro: bool = True,
        max_retries: int = 3,
        save_metadata: bool = True,
        user_request: Optional[str] = None,
        composition: Optional[str] = None
    ) -> bool:
        """
        Generate or edit an image using Gemini.

        Args:
            prompt: Text description of the image to generate
            images: List of input image paths for editing or reference
            aspect_ratio: Output aspect ratio (e.g., "16:9")
            resolution: Output resolution ("1K", "2K", or "4K")
            output: Output file path
            use_pro: Use Pro model (True) or standard (False)
            max_retries: Maximum number of retry attempts
            save_metadata: Save metadata YAML file alongside image
            user_request: Original user request/requirements
            composition: Reasoning/composition notes explaining prompt choices

        Returns:
            True if successful, False otherwise
        """
        # Initialize metadata dict to collect all generation info
        metadata: Dict[str, Any] = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "user_request": user_request,
            "composition": composition,
            "prompt": prompt,
            "parameters": {
                "aspect_ratio": aspect_ratio,
                "resolution": resolution if use_pro else "~1K (flash fixed)",
                "model": self.MODEL_PRO if use_pro else self.MODEL_FLASH,
                "model_name": "Gemini Pro" if use_pro else "Gemini Flash",
                "max_retries": max_retries,
            },
            "input_images": images or [],
            "output_file": output,
        }

        # Remove None values for cleaner YAML
        if user_request is None:
            del metadata["user_request"]
        if composition is None:
            del metadata["composition"]
        model = self.MODEL_PRO if use_pro else self.MODEL_FLASH
        model_name = "Gemini Pro" if use_pro else "Gemini Flash"

        print(f"Using {model_name} ({model})")
        print(f"Prompt: {prompt}")
        if use_pro:
            print(f"Aspect Ratio: {aspect_ratio}, Resolution: {resolution}")
        else:
            print(f"Aspect Ratio: {aspect_ratio} (Flash model uses fixed ~1K resolution)")

        # Build contents array
        contents = [prompt]

        # Add reference images if provided
        if images:
            print(f"Loading {len(images)} reference image(s)...")
            for img_path in images:
                try:
                    img = Image.open(img_path)
                    contents.append(img)
                    print(f"  - Loaded: {img_path}")
                except Exception as e:
                    print(f"Error loading image {img_path}: {e}")
                    return False

        # Configure generation parameters
        # Note: Flash model doesn't support imageSize, only aspectRatio
        if use_pro:
            config = types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=aspect_ratio,
                    image_size=resolution
                )
            )
        else:
            # Flash model: no imageSize parameter
            config = types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=aspect_ratio
                )
            )

        # Attempt generation with retries
        for attempt in range(max_retries):
            try:
                print(f"\nGenerating image (attempt {attempt + 1}/{max_retries})...")
                start_time = time.time()

                response = self.client.models.generate_content(
                    model=model,
                    contents=contents,
                    config=config
                )

                elapsed = time.time() - start_time
                print(f"Generation completed in {elapsed:.1f}s")

                # Extract and save the generated image
                image_saved = False
                metadata["generation"] = {
                    "elapsed_seconds": round(elapsed, 2),
                    "attempts": attempt + 1,
                }

                for part in response.candidates[0].content.parts:
                    if part.text is not None:
                        print(f"\nModel description: {part.text}")
                        metadata["model_description"] = part.text

                    elif part.inline_data is not None:
                        # Save the image
                        image = Image.open(BytesIO(part.inline_data.data))

                        # Ensure output directory exists
                        output_path = Path(output)
                        output_path.parent.mkdir(parents=True, exist_ok=True)

                        image.save(output)
                        print(f"\n✓ Image saved to: {output}")
                        print(f"  Size: {image.size[0]}x{image.size[1]} pixels")

                        metadata["output"] = {
                            "file": output,
                            "width": image.size[0],
                            "height": image.size[1],
                            "format": output_path.suffix.lstrip('.').upper(),
                        }
                        image_saved = True

                if not image_saved:
                    print("Warning: No image data found in response")
                    metadata["error"] = "No image data in response"
                    self._save_metadata(metadata, output)
                    return False

                # Collect token usage if available
                if hasattr(response, 'usage_metadata'):
                    usage = response.usage_metadata
                    metadata["usage"] = {
                        "input_tokens": usage.prompt_token_count,
                        "output_tokens": usage.candidates_token_count,
                        "total_tokens": usage.total_token_count,
                    }
                    print(f"\nToken usage:")
                    print(f"  Input: {usage.prompt_token_count}")
                    print(f"  Output: {usage.candidates_token_count}")
                    print(f"  Total: {usage.total_token_count}")

                # Save metadata file
                if save_metadata:
                    metadata_path = self._save_metadata(metadata, output)
                    print(f"✓ Metadata saved to: {metadata_path}")

                return True

            except Exception as e:
                error_msg = str(e)
                print(f"Error: {error_msg}")

                # Check if it's a rate limit error
                if "429" in error_msg or "rate limit" in error_msg.lower():
                    if attempt < max_retries - 1:
                        wait_time = (2 ** attempt) + 1
                        print(f"Rate limited. Waiting {wait_time}s before retry...")
                        time.sleep(wait_time)
                        continue

                # For other errors, don't retry
                if attempt < max_retries - 1:
                    print(f"Retrying...")
                    time.sleep(1)
                else:
                    print(f"Failed after {max_retries} attempts")
                    return False

        return False


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Gemini Image Generation CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate a simple image
  python image_gen.py "A sunset over mountains"

  # High-quality 4K image with custom aspect ratio
  python image_gen.py "A futuristic city at night" --resolution 4K --aspect-ratio 16:9

  # Fast generation using standard model
  python image_gen.py "A cat wearing sunglasses" --fast

  # Edit an existing image
  python image_gen.py "Convert to black and white" --images photo.jpg --output bw.png

  # Multi-image fusion
  python image_gen.py "Combine these into a collage" --images img1.jpg img2.jpg img3.jpg
        """
    )

    parser.add_argument(
        "prompt",
        type=str,
        help="Text prompt describing the image to generate or edit"
    )

    parser.add_argument(
        "-i", "--images",
        nargs="+",
        metavar="PATH",
        help="Input image path(s) for editing or multi-image fusion"
    )

    parser.add_argument(
        "-o", "--output",
        default="output.png",
        metavar="PATH",
        help="Output image file path (default: output.png)"
    )

    parser.add_argument(
        "--aspect-ratio",
        choices=GeminiImageCLI.ASPECT_RATIOS,
        default="1:1",
        help="Output image aspect ratio (default: 1:1)"
    )

    parser.add_argument(
        "--resolution",
        choices=GeminiImageCLI.RESOLUTIONS,
        default="2K",
        help="Output image resolution (default: 2K)"
    )

    parser.add_argument(
        "--fast",
        action="store_true",
        help="Use Gemini Flash for faster generation (fixed ~1K resolution)"
    )

    parser.add_argument(
        "--api-key",
        metavar="KEY",
        help="Gemini API key (or set GEMINI_API_KEY environment variable)"
    )

    parser.add_argument(
        "--retries",
        type=int,
        default=3,
        metavar="N",
        help="Maximum number of retry attempts (default: 3)"
    )

    parser.add_argument(
        "--no-metadata",
        action="store_true",
        help="Skip saving metadata YAML file"
    )

    parser.add_argument(
        "--user-request",
        metavar="TEXT",
        help="Original user request/requirements (for metadata)"
    )

    parser.add_argument(
        "--composition",
        metavar="TEXT",
        help="Reasoning/composition notes explaining prompt choices (for metadata)"
    )

    return parser


def main():
    """Main entry point for the CLI."""
    parser = create_parser()
    args = parser.parse_args()

    # Initialize the CLI
    cli = GeminiImageCLI(api_key=args.api_key)

    # Generate the image
    # Fast mode uses gemini-2.5-flash-image (faster, fixed ~1K resolution)
    # Pro mode uses gemini-3-pro-image-preview (slower, supports 1K/2K/4K)
    success = cli.generate_image(
        prompt=args.prompt,
        images=args.images,
        aspect_ratio=args.aspect_ratio,
        resolution=args.resolution,
        output=args.output,
        use_pro=not args.fast,
        max_retries=args.retries,
        save_metadata=not args.no_metadata,
        user_request=args.user_request,
        composition=args.composition
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
