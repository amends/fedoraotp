import importlib.machinery
import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "bin" / "otp-clipboard-listener"
loader = importlib.machinery.SourceFileLoader("otp_clipboard_listener", str(MODULE_PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
otp = importlib.util.module_from_spec(spec)
loader.exec_module(otp)


def test_extracts_schwab_style_warning_login_code_late_in_message():
    text = (
        "Watch out for scams. DON'T share this security code with anyone, "
        "EVEN IF THEY CLAIM to be from Schwab. Your code for online login is 123456."
    )

    assert otp.extract_otp(text) == "123456"


def test_extracts_10_digit_code_when_code_and_login_words_present():
    text = "Your code for online login is 1234567890. Do not share it."

    assert otp.extract_otp(text) == "1234567890"


def test_extracts_phone_context_otp_not_the_phone_number():
    text = "OTP for 2310990533 is 4279"

    assert otp.extract_otp(text) == "4279"


def test_extracts_capital_one_temporary_sign_in_code_before_digits():
    text = (
        "Capital One won't call you for this code. The temporary code you requested "
        "to sign-in is 654321. Please don't share this code with anyone."
    )

    assert otp.extract_otp(text) == "654321"


def test_extracts_sign_in_code_when_code_warning_is_separate_from_digits():
    text = (
        "Capital One won't call you for this code. Use 1234567890 to sign-in. "
        "Please don't share it with anyone."
    )

    assert otp.extract_otp(text) == "1234567890"


def test_ignores_order_number_even_with_code_word_in_product_copy():
    text = "Your order code 123456 shipped and tracking will update soon."

    assert otp.extract_otp(text) is None


def test_parse_notify_block_handles_multiline_chrome_message_body():
    lines = [
        "method call time=1780607553.579405 sender=:1.137 -> destination=org.freedesktop.Notifications serial=161 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify\n",
        '   string "Google Chrome"\n',
        "   uint32 0\n",
        '   string "file:///tmp/com.google.Chrome.scoped_dir.KzNkm4/logo.png"\n',
        '   string "Katherine Little"\n',
        '   string "messages.google.com\n',
        "\n",
        'Venmo: 742021 is your code for login. Don\'t share your code."\n',
        "   array [\n",
        '      string "default"\n',
        '      string "Activate"\n',
        "   ]\n",
        "   int32 -1\n",
    ]

    info = otp.parse_notify_block(lines)

    assert info == {
        "app": "Google Chrome",
        "summary": "Katherine Little",
        "body": "messages.google.com\n\nVenmo: 742021 is your code for login. Don't share your code.",
    }
    assert otp.extract_otp("\n".join(info.values())) == "742021"
