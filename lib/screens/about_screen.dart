import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class TeamMember {
  final String name;
  final String role;
  final String contribution;
  final String quote;
  final String? imagePath; // e.g. 'assets/images/shozen.jpg' — null → initials
  final Color accentColor;
  final String? github;
  final String? linkedin;
  final String? facebook;

  const TeamMember({
    required this.name,
    required this.role,
    required this.contribution,
    required this.quote,
    this.imagePath,
    required this.accentColor,
    this.github,
    this.linkedin,
    this.facebook,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }
}

// ─── Team data — fill in your real details ────────────────────────────────────

const List<TeamMember> _team = [
  TeamMember(
    name: 'Shams Pahlowan Soad',
    role: 'Mobile Developer',
    contribution:
        'Architected the Flutter app from scratch — BLE communication layer, '
        'real-time CarState model, voice command pipeline, and the full UI.',
    quote:
        'If it can\'t run on a microcontroller, is it even real engineering?',
    accentColor: Colors.deepOrange,
    imagePath: null, // replace with 'assets/images/shozen.jpg'
    github: 'https://github.com/',
    linkedin: 'https://linkedin.com/in/',
    facebook: 'https://facebook.com/',
  ),
  TeamMember(
    name: 'Meheraj Hasan',
    role: 'AI Engineer',
    contribution:
        'Designed the ESP32 circuit, wrote the motor-control firmware, and '
        'defined the BLE GATT characteristic protocol.',
    quote: 'Hardware is just software you can\'t git push.',
    accentColor: Color(0xFF00BCD4),
    imagePath: null,
    github: 'https://github.com/',
    linkedin: 'https://linkedin.com/in/',
    facebook: null,
  ),
  TeamMember(
    name: 'MD. Faysal Khan',
    role: 'UX & Interaction Design',
    contribution:
        'Led the HCI research, user testing sessions, and designed the control '
        'pad layout, mode toggle flows, and accessibility considerations.',
    quote: 'A button nobody clicks is a bug, not a feature.',
    accentColor: Color(0xFF66BB6A),
    imagePath: null,
    github: 'https://github.com/',
    linkedin: 'https://linkedin.com/in/',
    facebook: 'https://facebook.com/',
  ),
  TeamMember(
    name: 'Rifat Bhuiya',
    role: 'Systems & Integration',
    contribution:
        'Handled end-to-end integration testing, tuning the motor drift '
        'parameters, and documenting the full system architecture.',
    quote: 'It worked in theory. Then it worked in practice. Both felt good.',
    accentColor: Color(0xFFAB47BC),
    imagePath: null,
    github: 'https://github.com/',
    linkedin: null,
    facebook: 'https://facebook.com/',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'THE TEAM',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontSize: 26,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Cards ──
          PageView.builder(
            controller: _controller,
            itemCount: _team.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) =>
                _TeamCard(member: _team[index], index: index),
          ),

          // ── Dot indicator ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_team.length, (i) {
                final active = i == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? _team[_currentIndex].accentColor
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ── Swipe hint (only on first page) ──
          if (_currentIndex == 0)
            Positioned(
              bottom: 70,
              right: 32,
              child: Row(
                children: [
                  const Text(
                    'swipe',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white24,
                    size: 11,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Individual card ──────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final TeamMember member;
  final int index;

  const _TeamCard({required this.member, required this.index});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 80),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: member.accentColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: member.accentColor.withOpacity(0.12),
              blurRadius: 40,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // ── Top accent stripe ──
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      member.accentColor,
                      member.accentColor.withOpacity(0.3),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),

                      // ── Avatar ──
                      _Avatar(member: member),
                      const SizedBox(height: 20),

                      // ── Name ──
                      Text(
                        member.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // ── Role chip ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: member.accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: member.accentColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          member.role.toUpperCase(),
                          style: TextStyle(
                            color: member.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Divider ──
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white12,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Contribution ──
                      Text(
                        member.contribution,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.65,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // ── Quote ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"',
                              style: TextStyle(
                                color: member.accentColor,
                                fontSize: 28,
                                height: 0.9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                member.quote,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Social links ──
                      _SocialRow(member: member),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final TeamMember member;
  const _Avatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: member.accentColor.withOpacity(0.6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: member.accentColor.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: member.imagePath != null
            ? Image.asset(member.imagePath!, fit: BoxFit.cover)
            : Container(
                color: member.accentColor.withOpacity(0.15),
                child: Center(
                  child: Text(
                    member.initials,
                    style: TextStyle(
                      color: member.accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Social row ───────────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  final TeamMember member;
  const _SocialRow({required this.member});

  Future<void> _open(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (member.github != null)
          _SocialButton(
            icon: _GithubIcon(),
            label: 'GitHub',
            accentColor: member.accentColor,
            onTap: () => _open(member.github),
          ),
        if (member.github != null &&
            (member.linkedin != null || member.facebook != null))
          const SizedBox(width: 12),
        if (member.linkedin != null)
          _SocialButton(
            icon: const Icon(
              Icons.work_outline,
              size: 18,
              color: Colors.white70,
            ),
            label: 'LinkedIn',
            accentColor: member.accentColor,
            onTap: () => _open(member.linkedin),
          ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GitHub SVG icon (no package dependency) ─────────────────────────────────

class _GithubIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.code, size: 18, color: Colors.white70);
    // Swap for an actual SVG via flutter_svg if you prefer the GitHub mark
  }
}
