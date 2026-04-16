# ======================
# IMPORTS
# ======================
import discord
import aiohttp
import base64
import asyncio

from discord import app_commands


# ======================
# CONFIG
# ======================
BOT_TOKEN = ""

CARD_ID = ""
CARD_TOKEN = ""

GUILD_ID = 1485025809080127538

ALLOWED_ROLE_IDS = [
    1485026750261104752
]   


# ======================
# BOT
# ======================
class MyBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        intents.members = True
        intents.message_content = True

        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

        # кеш API
        self.nick_cache = {}

        # semaphore чтобы не убить Discord API
        self.semaphore = asyncio.Semaphore(5)

    # ======================
    # API (ASYNC + CACHE)
    # ======================
    async def get_spworlds_username(self, user_id: int):
        if user_id in self.nick_cache:
            return self.nick_cache[user_id]

        url = f"https://spworlds.ru/api/public/users/{user_id}"

        auth_str = f"{CARD_ID}:{CARD_TOKEN}"
        auth_b64 = base64.b64encode(auth_str.encode()).decode()

        headers = {
            "Authorization": f"Bearer {auth_b64}",
            "Accept": "application/json"
        }

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=headers, timeout=10) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        username = data.get("username")

                        if username:
                            self.nick_cache[user_id] = username

                        return username

        except Exception as e:
            print("API error:", e)

        return None

    # ======================
    # WORKER (ONE MEMBER)
    # ======================
    async def process_member(self, member: discord.Member):
        async with self.semaphore:
            try:
                old_nick = member.nick or member.name
                api_nick = await self.get_spworlds_username(member.id)

                if not api_nick:
                    return f"{member.mention} --> API error"

                if "|" in old_nick:
                    prefix = old_nick.split("|")[0].strip()
                    new_nick = f"{prefix} | {api_nick}"
                else:
                    new_nick = api_nick

                await member.edit(nick=new_nick)

                return f"{member.mention} <-- `{old_nick}` | [ссылка на Namemc](https://ru.namemc.com/profile/{api_nick}.1)"

            except Exception as e:
                return f"{member.mention} <-- error: {e}"


bot = MyBot()


# ======================
# EVENTS
# ======================
@bot.event
async def on_ready():
    print(f"Logged in as {bot.user}")

    guild = discord.Object(id=GUILD_ID)
    synced = await bot.tree.sync(guild=guild)

    print(f"Synced {len(synced)} commands")


@bot.event
async def on_member_join(member: discord.Member):
    new_nick = await bot.get_spworlds_username(member.id)

    if new_nick:
        try:
            await member.edit(nick=new_nick)
        except Exception as e:
            print("Nickname error:", e)


@bot.event
async def on_message(message: discord.Message):
    if message.author.bot:
        return

    if message.content.startswith("!form") and message.reference:
        referenced = await message.channel.fetch_message(
            message.reference.message_id
        )

        text = referenced.content or "(пусто)"

        bot_msg = await message.reply(f"```\n{text}\n```")
        await bot_msg.add_reaction("❌")

        try:
            await message.delete()
        except:
            pass


@bot.event
async def on_reaction_add(reaction: discord.Reaction, user: discord.User):
    if user.bot:
        return

    if str(reaction.emoji) == "❌" and reaction.message.author == bot.user:
        try:
            await reaction.message.delete()
        except:
            pass


# ======================
# COMMANDS
# ======================
@bot.tree.command(name="ping", description="Проверка бота")
@app_commands.guilds(discord.Object(id=GUILD_ID))
async def ping(interaction: discord.Interaction):
    await interaction.response.send_message("Pong!")


@bot.tree.command(name="role", description="Работа с ролью или пользователем")
@app_commands.guilds(discord.Object(id=GUILD_ID))
@app_commands.describe(
    role="Роль",
    user="Пользователь",
    action="Действие"
)
@app_commands.choices(action=[
    app_commands.Choice(name="info", value="info"),
    app_commands.Choice(name="changenick", value="changenick"),
])
async def role_command(
    interaction: discord.Interaction,
    role: discord.Role = None,
    user: discord.Member = None,
    action: app_commands.Choice[str] = None
):
    # права
    if not any(r.id in ALLOWED_ROLE_IDS for r in interaction.user.roles):
        await interaction.response.send_message("Нет прав.", ephemeral=True)
        return

    if not role and not user:
        await interaction.response.send_message("Укажи роль или пользователя.", ephemeral=True)
        return

    members = []
    if role:
        members.extend(role.members)
    if user:
        members.append(user)

    await interaction.response.defer()

    action_value = action.value if action else "info"

    # INFO
    if action_value == "info":
        tasks = [bot.get_spworlds_username(member.id) for member in members]
        nicks = await asyncio.gather(*tasks)
        lines = []
        for member, nick in zip(members, nicks):
            if nick:
                lines.append(
                    f"{member.mention} <-- `{member.nick or member.name}` "
                    f"| [ссылка на Namemc](https://ru.namemc.com/profile/{nick})"
                )
            else:
                lines.append(f"{member.mention} <-- API error")

        await interaction.followup.send("\n".join(lines))

    # CHANGENICK (PARALLEL)
    elif action_value == "changenick":

        tasks = [
            bot.process_member(member)
            for member in members
        ]

        results = await asyncio.gather(*tasks)

        await interaction.followup.send("\n".join(results))


# ======================
# RUN
# ======================
bot.run(BOT_TOKEN)
